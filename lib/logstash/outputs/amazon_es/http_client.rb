require "logstash/outputs/amazon_es"
require "cabin"
require "base64"
require "elasticsearch"

require_relative "aws_transport"

module LogStash::Outputs::AES
  class HttpClient
    attr_reader :client, :options, :client_options
    DEFAULT_OPTIONS = {
      :port => 80
    }

    def initialize(options={})
      @logger = Cabin::Channel.get
      @options = DEFAULT_OPTIONS.merge(options)
      @client = build_client(@options)
    end

    def template_install(name, template, force=false)
      if template_exists?(name) && !force
        @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
        return
      end
      template_put(name, template)
    end

    def bulk(actions)
      actionsbyindex = Hash.new { |hash, key| hash[key] = [] }
      actions.each do |action, args, source|
        if action == 'update'
          if args[:_id]
            source = { 'doc' => source }
            if @options[:doc_as_upsert]
              source['doc_as_upsert'] = true
            else
              source['upsert'] = args[:_upsert] if args[:_upsert]
            end
          else
            raise(LogStash::ConfigurationError, "Specifying action => 'update' without a document '_id' is not supported.")
          end
        end

        args.delete(:_upsert)

        index = args[:_index]
        if source
          actionsbyindex[index].push([ { action => args.except(:_index) }, source ])
        else
          actionsbyindex[index].push({ action => args.except(:_index) })
        end
      end

      merged_responses = nil
      actionsbyindex.each do |index, actionlist|
        bulk_response = @client.bulk(:index => index, :body => actionlist.flatten)
        merged_responses = self.class.merge_normalized_responses(merged_responses, self.class.normalize_bulk_response(bulk_response))
      end
      merged_responses
    end

    private
    def build_client(options)
      hosts = options[:hosts]
      port = options[:port]
      protocol = options[:protocol]
      client_settings = options[:client_settings] || {}

      uris = hosts.map do |host|
        "#{protocol}://#{host}:#{port}#{client_settings[:path]}".gsub(/[\/]+$/,'')
      end

      @client_options = {
        :hosts => uris,
        :region => options[:region],
        :transport_options => {
          :request => {:open_timeout => 0, :timeout => 60},  # ELB timeouts are set at 60
          :proxy => client_settings[:proxy],
        },
        :transport_class => Elasticsearch::Transport::Transport::HTTP::AWS
      }
      internal_options = @client_options.clone
      internal_options[:aws_access_key_id] = options[:aws_access_key_id]
      internal_options[:aws_secret_access_key] = options[:aws_secret_access_key]

      if options[:user] && options[:password] then
        token = Base64.strict_encode64(options[:user] + ":" + options[:password])
        internal_options[:headers] = { "Authorization" => "Basic #{token}" }
      end

      Elasticsearch::Client.new(internal_options)
    end

    def self.merge_normalized_responses(response_old, response_new)
      if response_old.nil?
        return response_new
      end

      return response_old.merge(response_new) do |key, oldval, newval|
        if key=="errors" and oldval
          next oldval
        elsif key=="statuses"
          if oldval
            next oldval + newval
          end
        end
        next newval
      end
    end

    def self.normalize_bulk_response(bulk_response)
      if bulk_response["errors"]
        # The structure of the response from the REST Bulk API is follows:
        # {"took"=>74, "errors"=>true, "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
        #                                                    "_type"=>"logs",
        #                                                    "_id"=>"AUxTS2C55Jrgi-hC6rQF",
        #                                                    "_version"=>1,
        #                                                    "status"=>400,
        #                                                    "error"=>"MapperParsingException[failed to parse]..."}}]}
        # where each `item` is a hash of {OPTYPE => Hash[]}. calling first, will retrieve
        # this hash as a single array with two elements, where the value is the second element (i.first[1])
        # then the status of that item is retrieved.
        {"errors" => true, "statuses" => bulk_response["items"].map { |i| i.first[1]['status'] }}
      else
        {"errors" => false}
      end
    end

    def template_exists?(name)
      @client.indices.get_template(:name => name)
      return true
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      return false
    end

    def template_put(name, template)
      @client.indices.put_template(:name => name, :body => template)
    end
  end
end
