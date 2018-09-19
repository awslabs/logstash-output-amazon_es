require "logstash/outputs/amazon_es"
require_relative "../../../spec/es_spec_helper"

describe "whitelisting error types in expected behavior" do
  let(:template) { '{"template" : "not important, will be updated by :index"}' }
  let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z") }
  let(:action1) { ["index", {:_id=>1, :_routing=>nil, :_index=>"logstash-2014.11.17", :_type=>"doc"}, event1] }
  let(:settings) { {"manage_template" => true,
                    "index" => "logstash-2014.11.17",
                    "template_overwrite" => true,
                    "hosts" => get_host_port(),
                    "protocol" => "http",
                    "port" => 9200,
                    "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                    "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }

  subject { LogStash::Outputs::ElasticSearch.new(settings) }

  before :each do
    allow(subject.logger).to receive(:warn)

    subject.register

    allow(subject.client).to receive(:maximum_seen_major_version).and_return(0)
    allow(subject.client).to receive(:bulk).and_return(
      {
        "errors" => true,
        "items" => [{
          "create" => {
            "status" => 409, 
            "error" => {
              "type" => "document_already_exists_exception",
              "reason" => "[shard] document already exists"
            }
          }
        }]
      })

    subject.multi_receive([event1])
  end

  after :each do
    subject.close
  end

  describe "when failure logging is enabled for everything" do
    it "should log a failure on the action" do
      expect(subject.logger).to have_received(:warn).with("Failed action.", anything)
    end
  end

  describe "when failure logging is disabled for docuemnt exists error" do
    let(:settings) { super.merge("failure_type_logging_whitelist" => ["document_already_exists_exception"]) }

    it "should log a failure on the action" do
      expect(subject.logger).not_to have_received(:warn).with("Failed action.", anything)
    end
  end

end
