require_relative "../../../spec/amazon_es_spec_helper"
require "logstash/outputs/amazon_es"
require "elasticsearch"

describe "outputs/amazon_es" do
  describe "http client create" do
    subject(:eso) { LogStash::Outputs::AmazonES.new(options) }

    let(:manticore_host) do
      eso.client.send(:client).transport.options[:hosts].first
    end

    around(:each) do |block|
      thread = eso.register
      block.call()
      thread.kill()
    end

    describe "with path" do
      let(:options) do
        { "index" => "my-index",
          "hosts" => "localhost",
          "path" => "some-path" }
      end

      it "should properly create a URI with the path" do
        expect(eso.path).to eql(options["path"])
      end

      it "should properly set the path on the HTTP client" do
        expect(manticore_host).to include("/" + options["path"])
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:eso) do
          LogStash::Outputs::AmazonES.new(options.merge("path" => "/some-path/"))
        end

        it "should properly set the path on the HTTP client without adding slashes" do
          expect(manticore_host).to include(options["path"])
        end
      end
    end

    context 'scheme' do
      subject { eso.scheme }

      describe 'default' do
        let(:options) { {} }
        it { is_expected.to eq('http') }
      end

      describe 'set' do
        let(:options) { { 'scheme' => 'https' } }

        it { is_expected.to eq('https') }
      end
    end
  end
end
