require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/amazon_es/http_client"
require "java"

describe LogStash::Outputs::AES::HttpClient do
  context "successful" do
    it "should map correctly" do
      bulk_response = {"took"=>74, "errors"=>false, "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
                                                                          "_type"=>"logs", "_id"=>"AUxTS2C55Jrgi-hC6rQF",
                                                                          "_version"=>1, "status"=>201}}]} 
      actual = LogStash::Outputs::AES::HttpClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> false}
    end
  end

  context "contains failures" do
    it "should map correctly" do
      bulk_response = {"took"=>71, "errors"=>true,
                       "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
                                             "_type"=>"logs", "_id"=>"AUxTQ_OI5Jrgi-hC6rQB", "status"=>400,
                                             "error"=>"MapperParsingException[failed to parse]..."}}]}
      actual = LogStash::Outputs::AES::HttpClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> true, "statuses"=> [400]}
    end
  end

  describe "sniffing" do
    let(:base_options) { {:hosts => ["127.0.0.1"] }}
    let(:client) { LogStash::Outputs::AES::HttpClient.new(base_options.merge(client_opts)) }
    let(:transport) { client.client.transport }

    before do
      allow(transport).to receive(:reload_connections!)
    end
  end
end
