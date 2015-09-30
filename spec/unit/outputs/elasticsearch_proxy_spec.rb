require_relative "../../../spec/amazon_es_spec_helper"
require 'stud/temporary'
require 'elasticsearch'
require "logstash/outputs/amazon_es"

describe "Proxy option" do
  let(:settings) {
    {
      "hosts" => "node01",
      "proxy" => proxy
    }
  }
  subject {
    LogStash::Outputs::AmazonES.new(settings)
  }

  before do
    allow(::Elasticsearch::Client).to receive(:new).with(any_args)
  end

  describe "valid configs" do
    before do
      subject.register
    end

    context "when specified as a string" do
      let(:proxy) { "http://127.0.0.1:1234" }

      it "should set the proxy to the exact value" do
        expect(::Elasticsearch::Client).to have_received(:new) do |options|
          expect(options[:transport_options][:proxy]).to eql(proxy)
        end
      end
    end

    context "when specified as a hash" do
      let(:proxy) { {"hosts" => "127.0.0.1", "protocol" => "http"} }

      it "should pass through the proxy values as symbols" do
        expected = {:hosts => proxy["hosts"], :protocol => proxy["protocol"]}
        expect(::Elasticsearch::Client).to have_received(:new) do |options|
          expect(options[:transport_options][:proxy]).to eql(expected)
        end
      end
    end
  end

  describe "invalid configs" do
    let(:proxy) { ["bad", "stuff"] }

    it "should have raised an exception" do
      expect {
        subject.register
      }.to raise_error(LogStash::ConfigurationError)
    end
  end

end
