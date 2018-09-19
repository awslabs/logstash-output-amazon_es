require_relative "../../../spec/es_spec_helper"
require "flores/random"
require "logstash/outputs/amazon_es"

describe LogStash::Outputs::ElasticSearch do
  subject { described_class.new(options) }
  let(:options) { { "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                    "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
  let(:maximum_seen_major_version) { rand(100) }

  let(:do_register) { true }

  before(:each) do
    if do_register
      subject.register

      # Rspec mocks can't handle background threads, so... we can't use any
      allow(subject.client.pool).to receive(:start_resurrectionist)
      allow(subject.client.pool).to receive(:start_sniffer)
      allow(subject.client.pool).to receive(:healthcheck!)
      allow(subject.client).to receive(:maximum_seen_major_version).at_least(:once).and_return(maximum_seen_major_version)
      subject.client.pool.adapter.manticore.respond_with(:body => "{}")
    end
  end

  after(:each) do
    subject.close
  end


  context "with an active instance" do
    let(:options) {
      {
        "index" => "my-index",
        "hosts" => ["localhost"],
        "path" => "some-path",
        "manage_template" => false,
        "port" => 9200,
        "protocol" => "http",
        "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
        "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      }
    }

    let(:manticore_urls) { subject.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    describe "getting a document type" do
      context "if document_type isn't set" do
        let(:options) { super.merge("document_type" => nil)}
        context "for 7.x amazon_es clusters" do
          let(:maximum_seen_major_version) { 7 }
          it "should return '_doc'" do
            expect(subject.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("_doc")
          end
        end

        context "for 6.x amazon_es clusters" do
          let(:maximum_seen_major_version) { 6 }
          it "should return 'doc'" do
            expect(subject.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("doc")
          end
        end

        context "for < 6.0 amazon_es clusters" do
          let(:maximum_seen_major_version) { 5 }
          it "should get the type from the event" do
            expect(subject.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("foo")
          end
        end
      end

      context "with 'document type set'" do
        let(:options) { super.merge("document_type" => "bar")}
        it "should get the event type from the 'document_type' setting" do
          expect(subject.send(:get_event_type, LogStash::Event.new())).to eql("bar")
        end
      end

      context "with a bad type event field in a < 6.0 es cluster" do
        let(:maximum_seen_major_version) { 5 }
        let(:type_arg) { ["foo"] }
        let(:result) { subject.send(:get_event_type, LogStash::Event.new("type" => type_arg)) }

        before do
          allow(subject.instance_variable_get(:@logger)).to receive(:warn)
          result
        end

        it "should call @logger.warn and return nil" do
          expect(subject.instance_variable_get(:@logger)).to have_received(:warn).with(/Bad event type!/, anything).once
        end

        it "should set the type to the stringified value" do
          expect(result).to eql(type_arg.to_s)
        end
      end
    end

    describe "with auth" do
      let(:user) { "myuser" }
      let(:password) { ::LogStash::Util::Password.new("mypassword") }

      shared_examples "an authenticated config" do
        it "should set the URL auth correctly" do
          expect(manticore_url.user).to eq user
        end
      end

      context "as part of a URL" do
        let(:options) {
          super.merge("hosts" => ["http://#{user}:#{password.value}@localhost:9200"])
        }

        include_examples("an authenticated config")
      end

      context "as a hash option" do
          let(:options) {
            super.merge!(
              "user" => user,
              "password" => password
            )
        }

        include_examples("an authenticated config")
      end
    end

    describe "with path" do
      it "should properly create a URI with the path" do
        expect(subject.path).to eql(options["path"])
      end

        it "should properly set the path on the HTTP client adding slashes" do
        expect(manticore_url.path).to eql("/" + options["path"] + "/")
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:options) { super.merge("path" => "/some-path/") }

        it "should properly set the path on the HTTP client without adding slashes" do
          expect(manticore_url.path).to eql(options["path"])
        end
      end

      context "with a URI based path" do
        let(:options) do
          o = super()
          o.delete("pat˙h")
          o["hosts"] = ["http://localhost:9200/mypath/"]
          o["port"] = 9200
          o["protocol"] = 'http'
          o["aws_access_key_id"] = "AAAAAAAAAAAAAAAAAAAA"
          o["aws_secret_access_key"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
          o
        end
        let(:client_host_path) { manticore_url.path }


        context "with a path option but no URL path" do
          let(:options) do
            o = super()
            o["path"] = "/override/"
            o["hosts"] = ["http://localhost:9200"]
            o["port"] = 9200
            o["protocol"] = 'http'
            o["aws_access_key_id"] = "AAAAAAAAAAAAAAAAAAAA"
            o["aws_secret_access_key"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            o
          end

          it "should initialize without error" do
            expect { subject }.not_to raise_error
          end

          it "should use the option path" do
            expect(client_host_path).to eql("/override/")
          end
        end

        # If you specify the path in two spots that is an error!
        context "with a path option and a URL path" do
          let(:do_register) { false } # Register will fail
          let(:options) do
            o = super()
            o["path"] = "/override"
            o["hosts"] = ["http://localhost:9200/mypath/"]
            o
          end

          it "should initialize with an error" do
            expect { subject.register }.to raise_error(LogStash::ConfigurationError)
          end
        end
      end
    end

    describe "without a port specified" do
      let(:options) { super.merge('hosts' => 'localhost') }
      it "should properly set the default port (9200) on the HTTP client" do
        expect(manticore_url.port).to eql(9200)
      end
    end

    describe "#multi_receive" do
      let(:events) { [double("one"), double("two"), double("three")] }
      let(:events_tuples) { [double("one t"), double("two t"), double("three t")] }

      before do
        allow(subject).to receive(:retrying_submit).with(anything)
        events.each_with_index do |e,i|
          et = events_tuples[i]
          allow(subject).to receive(:event_action_tuple).with(e).and_return(et)
        end
        subject.multi_receive(events)
      end

    end

    context "429 errors" do
      let(:event) { ::LogStash::Event.new("foo" => "bar") }
      let(:error) do
        ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(
          429, double("url").as_null_object, double("request body"), double("response body")
        )
      end
      let(:logger) { double("logger").as_null_object }
      let(:response) { { :errors => [], :items => [] } }

      before(:each) do

        i = 0
        bulk_param =  [["index", anything, event.to_hash]]

        allow(subject).to receive(:logger).and_return(logger)

        # Fail the first time bulk is called, succeed the next time
        allow(subject.client).to receive(:bulk).with(bulk_param) do
          i += 1
          if i == 1
            raise error
          end
        end.and_return(response)
        subject.multi_receive([event])
      end

      it "should retry the 429 till it goes away" do
        expect(subject.client).to have_received(:bulk).twice
      end

      it "should log a debug message" do
        expect(subject.logger).to have_received(:debug).with(/Encountered a retryable error/i, anything)
      end
    end
  end

  context "with timeout set" do
    let(:listener) { Flores::Random.tcp_listener }
    let(:port) { listener[2] }
    let(:options) do
      {
        "manage_template" => false,
        "hosts" => "localhost:#{port}",
        "timeout" => 0.1, # fast timeout,
        "port" => listener[2],
        "protocol" => "http",
        "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
        "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      }
    end

    before do
      # Expect a timeout to be logged.
      expect(subject.logger).to receive(:error).with(/Attempted to send a bulk request to Elasticsearch/i, anything).at_least(:once)
      expect(subject.client).to receive(:bulk).at_least(:twice).and_call_original
    end

    it "should fail after the timeout" do
      #pending("This is tricky now that we do healthchecks on instantiation")
      Thread.new { subject.multi_receive([LogStash::Event.new]) }

      # Allow the timeout to occur
      sleep 6
    end
  end

  describe "the action option" do
    context "with a sprintf action" do
      let(:options) { {"action" => "%{myactionfield}" , "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                       "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }

      let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }

      it "should interpolate the requested action value when creating an event_action_tuple" do
        expect(subject.event_action_tuple(event).first).to eql("update")
      end
    end

    context "with a sprintf action equals to update" do
      let(:options) { {"action" => "%{myactionfield}", "upsert" => '{"message": "some text"}' ,
                       "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                       "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }

      let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }

      it "should obtain specific action's params from event_action_tuple" do
        expect(subject.event_action_tuple(event)[1]).to include(:_upsert)
      end
    end

    context "with an invalid action" do
      let(:options) { {"action" => "SOME Garbaaage",
                       "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                       "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end
    end
  end

  describe "SSL end to end" do
    let(:do_register) { false } # skip the register in the global before block, as is called here.
    let(:manticore_double) do
      double("manticoreX#{self.inspect}")
    end

    before(:each) do
      response_double = double("manticore response").as_null_object
      # Allow healtchecks
      allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
      allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
      allow(manticore_double).to receive(:close)

      allow(::Manticore::Client).to receive(:new).and_return(manticore_double)
      subject.register
    end

    shared_examples("an encrypted client connection") do
      it "should enable SSL in manticore" do
        expect(subject.client.pool.urls.map(&:scheme).uniq).to eql(['https'])
      end
    end


    context "With the 'ssl' option" do
      let(:options) { {"ssl" => true,
                       "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                       "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}}

      include_examples("an encrypted client connection")
    end

    context "With an https host" do
      let(:options) { {"hosts" => "https://localhost",
                       "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                       "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
      include_examples("an encrypted client connection")
    end
  end

  describe "retry_on_conflict" do
    let(:num_retries) { 123 }
    let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }
    let(:options) { { 'retry_on_conflict' => num_retries ,
                      "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                      "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }

    context "with a regular index" do
      let(:options) { super.merge("action" => "index") }

      it "should not set the retry_on_conflict parameter when creating an event_action_tuple" do
        allow(subject.client).to receive(:maximum_seen_major_version).and_return(maximum_seen_major_version)
        action, params, event_data = subject.event_action_tuple(event)
        expect(params).not_to include({:_retry_on_conflict => num_retries})
      end
    end

    context "using a plain update" do
      let(:options) { super.merge("action" => "update", "retry_on_conflict" => num_retries, "document_id" => 1) }

      it "should set the retry_on_conflict parameter when creating an event_action_tuple" do
        action, params, event_data = subject.event_action_tuple(event)
        expect(params).to include({:_retry_on_conflict => num_retries})
      end
    end

    context "with a sprintf action that resolves to update" do
      let(:options) { super.merge("action" => "%{myactionfield}", "retry_on_conflict" => num_retries, "document_id" => 1) }

      it "should set the retry_on_conflict parameter when creating an event_action_tuple" do
        action, params, event_data = subject.event_action_tuple(event)
        expect(params).to include({:_retry_on_conflict => num_retries})
        expect(action).to eq("update")
      end
    end
  end

  describe "sleep interval calculation" do
    let(:retry_max_interval) { 64 }
    let(:options) { { "retry_max_interval" => retry_max_interval ,
                      "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                      "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }

    it "should double the given value" do
      expect(subject.next_sleep_interval(2)).to eql(4)
      expect(subject.next_sleep_interval(32)).to eql(64)
    end

    it "should not increase the value past the max retry interval" do
      sleep_interval = 2
      100.times do
        sleep_interval = subject.next_sleep_interval(sleep_interval)
        expect(sleep_interval).to be <= retry_max_interval
      end
    end
  end

  describe "stale connection check" do
    let(:validate_after_inactivity) { 123 }
    let(:options) { { "validate_after_inactivity" => validate_after_inactivity ,
                      "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                      "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
    let(:do_register) { false }

    before :each do
      allow(::Manticore::Client).to receive(:new).with(any_args).and_call_original
    end

    after :each do
      subject.close
    end

    it "should set the correct http client option for 'validate_after_inactivity'" do
      subject.register
      expect(::Manticore::Client).to have_received(:new) do |options|
        expect(options[:check_connection_timeout]).to eq(validate_after_inactivity)
      end
    end
  end

  describe "custom parameters" do

    let(:manticore_urls) { subject.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    let(:custom_parameters_hash) { { "id" => 1, "name" => "logstash" } }
    let(:custom_parameters_query) { custom_parameters_hash.map {|k,v| "#{k}=#{v}" }.join("&") }

    context "using non-url hosts" do

      let(:options) {
        {
          "index" => "my-index",
          "hosts" => ["localhost:9200"],
          "path" => "some-path",
          "parameters" => custom_parameters_hash,
          "port" => 9200,
          "protocol" => "http",
          "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
          "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        }
      }

      it "creates a URI with the added parameters" do
        expect(subject.parameters).to eql(custom_parameters_hash)
      end

      it "sets the query string on the HTTP client" do
        expect(manticore_url.query).to eql(custom_parameters_query)
      end
    end

    context "using url hosts" do

      context "with embedded query parameters" do
        let(:options) {
          { "hosts" => ["http://localhost:9200/path?#{custom_parameters_query}"] ,
            "port" => 9200,
            "protocol" => "http",
            "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
            "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}
        }

        it "sets the query string on the HTTP client" do
          expect(manticore_url.query).to eql(custom_parameters_query)
        end
      end

      context "with explicit query parameters" do
        let(:options) {
          {
            "hosts" => ["http://localhost:9200/path"],
            "parameters" => custom_parameters_hash,
            "port" => 9200,
            "protocol" => "http",
            "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
            "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
          }
        }

        it "sets the query string on the HTTP client" do
          expect(manticore_url.query).to eql(custom_parameters_query)
        end
      end

      context "with explicit query parameters and existing url parameters" do
        let(:existing_query_string) { "existing=param" }
        let(:options) {
          {
            "hosts" => ["http://localhost:9200/path?#{existing_query_string}"],
            "parameters" => custom_parameters_hash,
            "port" => 9200,
            "protocol" => "http",
            "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
            "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
          }
        }

        it "keeps the existing query string" do
          expect(manticore_url.query).to include(existing_query_string)
        end

        it "includes the new query string" do
          expect(manticore_url.query).to include(custom_parameters_query)
        end

        it "appends the new query string to the existing one" do
          expect(manticore_url.query).to eql("#{existing_query_string}&#{custom_parameters_query}")
        end
      end
    end
  end

  context 'handling amazon_es document-level status meant for the DLQ' do
    let(:options) { { "manage_template" => false ,
                      "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                      "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
    let(:logger)  { subject.instance_variable_get(:@logger) }

    context 'when @dlq_writer is nil' do
      before { subject.instance_variable_set '@dlq_writer', nil }

      context 'resorting to previous behaviour of logging the error' do
        context 'getting an invalid_index_name_exception' do
          it 'should log at ERROR level' do
            expect(logger).to receive(:error).with(/Could not index/, hash_including(:status, :action, :response))
            mock_response = { 'index' => { 'error' => { 'type' => 'invalid_index_name_exception' } } }
            subject.handle_dlq_status("Could not index event to Elasticsearch.",
              [:action, :params, :event], :some_status, mock_response)
          end
        end

        context 'when getting any other exception' do
          it 'should log at WARN level' do
            expect(logger).to receive(:warn).with(/Could not index/, hash_including(:status, :action, :response))
            mock_response = { 'index' => { 'error' => { 'type' => 'illegal_argument_exception' } } }
            subject.handle_dlq_status("Could not index event to Elasticsearch.",
              [:action, :params, :event], :some_status, mock_response)
          end
        end

        context 'when the response does not include [error]' do
          it 'should not fail, but just log a warning' do
            expect(logger).to receive(:warn).with(/Could not index/, hash_including(:status, :action, :response))
            mock_response = { 'index' => {} }
            expect do
              subject.handle_dlq_status("Could not index event to Elasticsearch.",
                [:action, :params, :event], :some_status, mock_response)
            end.to_not raise_error
          end
        end
      end
    end

    # DLQ writer always nil, no matter what I try here. So mocking it all the way
    context 'when DLQ is enabled' do
      let(:dlq_writer) { double('DLQ writer') }
      before { subject.instance_variable_set('@dlq_writer', dlq_writer) }

      # Note: This is not quite the desired behaviour.
      # We should still log when sending to the DLQ.
      # This shall be solved by another issue, however: logstash-output-amazon_es#772
      it 'should send the event to the DLQ instead, and not log' do
        expect(dlq_writer).to receive(:write).with(:event, /Could not index/)
        mock_response = { 'index' => { 'error' => { 'type' => 'illegal_argument_exception' } } }
        subject.handle_dlq_status("Could not index event to Elasticsearch.",
          [:action, :params, :event], :some_status, mock_response)
      end
    end
  end

  describe "custom headers" do
    let(:manticore_options) { subject.client.pool.adapter.manticore.instance_variable_get(:@options) } 

    context "when set" do
      let(:headers) { { "X-Thing" => "Test" } }
      let(:options) { { "custom_headers" => headers ,
                        "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                        "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
      it "should use the custom headers in the adapter options" do
        expect(manticore_options[:headers]).to eq(headers)
      end
    end

    context "when not set" do
      it "should have no headers" do
        expect(manticore_options[:headers]).to be_empty
      end
    end
  end
end
