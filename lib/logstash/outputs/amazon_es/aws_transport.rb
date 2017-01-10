require 'faraday'
require 'faraday_middleware'
require 'aws-sdk-core'
require 'elasticsearch'
require 'elasticsearch-transport'
require 'manticore'
require 'faraday/adapter/manticore'

#
require 'uri'

require_relative "aws_v4_signer"


module Elasticsearch
  module Transport
    module Transport
      module HTTP

        # Transport implementation, which V4 Signs requests using the [_Faraday_](https://rubygems.org/gems/faraday)
        # library for abstracting the HTTP client.
        #
        # @see Transport::Base
        #
        class AWS
          include Elasticsearch::Transport::Transport::Base
          

          DEFAULT_PORT = 80
          DEFAULT_PROTOCOL = "http"    
          
          CredentialConfig = Struct.new(
            :access_key_id,
            :secret_access_key,
            :session_token,
            :profile,
            :instance_profile_credentials_retries,
            :instance_profile_credentials_timeout,
            :region
          )      

          # Performs the request by invoking {Transport::Base#perform_request} with a block.
          #
          # @return [Response]
          # @see    Transport::Base#perform_request
          #
          def perform_request(method, path, params={}, body=nil)
            super do |connection, url|
              response = connection.connection.run_request \
               method.downcase.to_sym,
                url,
                ( body ? __convert_to_json(body) : nil ),
                {}

              Response.new response.status, response.body, response.headers
            end
          end

          # Builds and returns a collection of connections.
          #
          # @return [Connections::Collection]
          #
          def __build_connections
            region = options[:region]
            access_key_id = options[:aws_access_key_id] || nil
            secret_access_key = options[:aws_secret_access_key] || nil
            session_token = options[:session_token] || nil
            profile = options[:profile] || 'default'
            instance_cred_retries = options[:instance_profile_credentials_retries] || 0
            instance_cred_timeout = options[:instance_profile_credentials_timeout] || 1
            
            credential_config = CredentialConfig.new(access_key_id, secret_access_key, session_token, profile,
                                                     instance_cred_retries, instance_cred_timeout, region)
            credentials = Aws::CredentialProviderChain.new(credential_config).resolve

            Connections::Collection.new \
              :connections => hosts.map { |host|
                host[:protocol]   = host[:scheme] || DEFAULT_PROTOCOL
                host[:port]     ||= DEFAULT_PORT
                url               = __full_url(host)
                                  
                aes_connection = ::Faraday::Connection.new(url,  (options[:transport_options] || {})) do |faraday|
                  faraday.request :aws_v4_signer,
                                        credentials: credentials,
                                        service_name: 'es',
                                        region: region
                  faraday.adapter :manticore
                end
                
                Connections::Connection.new \
                  :host => host,
                  :connection => aes_connection
              },
              :selector_class => options[:selector_class],
              :selector => options[:selector]
          end

          # Returns an array of implementation specific connection errors.
          #
          # @return [Array]
          #
          def host_unreachable_exceptions
            [::Faraday::Error::ConnectionFailed, ::Faraday::Error::TimeoutError]
          end
        end
      end
    end
  end
end
