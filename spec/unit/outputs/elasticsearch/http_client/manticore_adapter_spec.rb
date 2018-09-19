require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/amazon_es/http_client"

describe LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter do
  let(:logger) { Cabin::Channel.get }
  let(:options) { {:aws_access_key_id => 'AAAAAAAAAAAAAAAAAAAA',
                   :aws_secret_access_key => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'} }

  subject { described_class.new(logger, options) }

  it "should raise an exception if requests are issued after close" do
    subject.close
    expect { subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, '/') }.to raise_error(::Manticore::ClientStoppedException)
  end

  it "should implement host unreachable exceptions" do
    expect(subject.host_unreachable_exceptions).to be_a(Array)
  end


  describe "bad response codes" do
    let(:uri) { ::LogStash::Util::SafeURI.new("http://localhost:9200") }

    it "should raise a bad response code error" do
      resp = double("response")
      allow(resp).to receive(:call)
      allow(resp).to receive(:code).and_return(500)
      allow(resp).to receive(:body).and_return("a body")

      expect(subject.manticore).to receive(:get).
        with(uri.to_s + "/", anything).
        and_return(resp)

      uri_with_path = uri.clone
      uri_with_path.path = "/"

      expect(::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError).to receive(:new).
        with(resp.code, uri_with_path, nil, resp.body).and_call_original

      expect do
        subject.perform_request(uri, :get, "/")
      end.to raise_error(::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError)
    end
  end

  describe "format_url" do
    let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/") }
    let(:path) { "_bulk" }
    subject { described_class.new(double("logger"),
                                  {:aws_access_key_id => 'AAAAAAAAAAAAAAAAAAAA',
                                   :aws_secret_access_key => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'} ) }

    it "should add the path argument to the uri's path" do
      expect(subject.format_url(url, path).path).to eq("/path/_bulk")
    end

    context "when uri contains query parameters" do
      let(:query_params) { "query=value&key=value2" }
      let(:url) { ::LogStash::Util::SafeURI.new("http://localhost:9200/path/?#{query_params}") }
      let(:formatted) { subject.format_url(url, path)}


      it "should retain query_params after format" do
        expect(formatted.query).to eq(query_params)
      end
      
      context "and the path contains query parameters" do
        let(:path) { "/special_path?specialParam=123" }

        it "should join the query correctly" do
          expect(formatted.query).to eq(query_params + "&specialParam=123")
        end
      end
    end
    
    context "when the path contains query parameters" do
      let(:path) { "/special_bulk?pathParam=1"}
      let(:formatted) { subject.format_url(url, path) }
      
      it "should add the path correctly" do
        expect(formatted.path).to eq("#{url.path}special_bulk")
      end 
      
      it "should add the query parameters correctly" do
        expect(formatted.query).to eq("pathParam=1")
      end
    end

    context "when uri contains credentials" do
      let(:url) { ::LogStash::Util::SafeURI.new("http://myuser:mypass@localhost:9200") }
      let(:formatted) { subject.format_url(url, path) }

      it "should remove credentials after format" do
        expect(formatted.userinfo).to be_nil
      end
    end
  end

  describe "integration specs", :integration => true do
    it "should perform correct tests without error" do
      resp = subject.perform_request(::LogStash::Util::SafeURI.new("http://localhost:9200"), :get, "/")
      expect(resp.code).to eql(200)
    end
  end
end
