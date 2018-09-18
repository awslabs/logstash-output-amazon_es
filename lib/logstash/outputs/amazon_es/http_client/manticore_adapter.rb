require 'manticore'
require 'cgi'
require 'aws-sdk-core'
require 'uri'

module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  DEFAULT_HEADERS = { "content-type" => "application/json" }

  CredentialConfig = Struct.new(
      :access_key_id,
      :secret_access_key,
      :session_token,
      :profile,
      :instance_profile_credentials_retries,
      :instance_profile_credentials_timeout,
      :region)

  class ManticoreAdapter
    attr_reader :manticore, :logger

    def initialize(logger, options={})
      @logger = logger
      options = options.clone || {}
      options[:ssl] = options[:ssl] || {}

      # We manage our own retries directly, so let's disable them here
      options[:automatic_retries] = 0
      # We definitely don't need cookies
      options[:cookies] = false

      @client_params = {:headers => DEFAULT_HEADERS.merge(options[:headers]|| {}),}

      @port =  options[:port] || 9200
      @protocol =  options[:protocol] || 'http'
      @region =   options[:region] || 'us-east-1'
      @aws_access_key_id =  options[:aws_access_key_id] || nil
      @aws_secret_access_key = options[:aws_secret_access_key] || nil
      @session_token = options[:session_token] || nil
      @profile = options[:profile] || 'default'
      @instance_cred_retries = options[:instance_profile_credentials_retries] || 0
      @instance_cred_timeout = options[:instance_profile_credentials_timeout] || 1

      if options[:proxy]
        options[:proxy] = manticore_proxy_hash(options[:proxy])
      end
      
      @manticore = ::Manticore::Client.new(options)
    end
    
    # Transform the proxy option to a hash. Manticore's support for non-hash
    # proxy options is broken. This was fixed in https://github.com/cheald/manticore/commit/34a00cee57a56148629ed0a47c329181e7319af5
    # but this is not yet released
    def manticore_proxy_hash(proxy_uri)
      [:scheme, :port, :user, :password, :path].reduce(:host => proxy_uri.host) do |acc,opt|
        value = proxy_uri.send(opt)
        acc[opt] = value unless value.nil? || (value.is_a?(String) && value.empty?)
        acc
      end
    end

    def client
      @manticore
    end



    # Performs the request by invoking {Transport::Base#perform_request} with a block.
    #
    # @return [Response]
    # @see    Transport::Base#perform_request
    #
    def perform_request(url, method, path, params={}, body=nil)
      # Perform 2-level deep merge on the params, so if the passed params and client params will both have hashes stored on a key they
      # will be merged as well, instead of choosing just one of the values
      params = (params || {}).merge(@client_params) { |key, oldval, newval|
        (oldval.is_a?(Hash) && newval.is_a?(Hash)) ? oldval.merge(newval) : newval
      }
      params[:headers] = params[:headers].clone


      params[:body] = body if body

      if url.user
        params[:auth] = { 
          :user => CGI.unescape(url.user),
          # We have to unescape the password here since manticore won't do it
          # for us unless its part of the URL
          :password => CGI.unescape(url.password), 
          :eager => true 
        }
      end

      request_uri = format_url(url, path)

      if @protocol == "https"
        url = URI::HTTPS.build({:host=>URI(request_uri.to_s).host, :port=>@port.to_s, :path=>path})
      else
        url = URI::HTTP.build({:host=>URI(request_uri.to_s).host, :port=>@port.to_s, :path=>path})
      end


      key = Seahorse::Client::Http::Request.new(options={:endpoint=>url, :http_method => method.to_s.upcase,
                                                       :headers => params[:headers],:body => params[:body]})



      credential_config = CredentialConfig.new(@aws_access_key_id, @aws_secret_access_key, @session_token, @profile, @instance_cred_retries, @instance_cred_timeout, @region)


      credentials = Aws::CredentialProviderChain.new(credential_config).resolve
      aws_signer = Aws::Signers::V4.new(credentials, 'es', @region )


      signed_key =  aws_signer.sign(key)
      params[:headers] =  params[:headers].merge(signed_key.headers)



      resp = @manticore.send(method.downcase, request_uri.to_s, params)

      # Manticore returns lazy responses by default
      # We want to block for our usage, this will wait for the repsonse
      # to finish
      resp.call
      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      if resp.code < 200 || resp.code > 299 && resp.code != 404
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(resp.code, request_uri, body, resp.body)
      end

      resp
    end

    def format_url(url, path_and_query=nil)
      request_uri = url.clone
      
      # We excise auth info from the URL in case manticore itself tries to stick
      # sensitive data in a thrown exception or log data
      request_uri.user = nil
      request_uri.password = nil

      return request_uri.to_s if path_and_query.nil?
      
      parsed_path_and_query = java.net.URI.new(path_and_query)
      
      query = request_uri.query
      parsed_query = parsed_path_and_query.query
      
      new_query_parts = [request_uri.query, parsed_path_and_query.query].select do |part|
        part && !part.empty? # Skip empty nil and ""
      end
      
      request_uri.query = new_query_parts.join("&") unless new_query_parts.empty?
      
      request_uri.path = "#{request_uri.path}/#{parsed_path_and_query.path}".gsub(/\/{2,}/, "/")
        
      request_uri
    end

    def close
      @manticore.close
    end

    def host_unreachable_exceptions
      [::Manticore::Timeout,::Manticore::SocketException, ::Manticore::ClientProtocolException, ::Manticore::ResolutionFailure, Manticore::SocketTimeout]
    end
  end
end; end; end; end
