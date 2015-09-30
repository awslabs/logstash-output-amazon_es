require_relative "../../../spec/amazon_es_spec_helper"

describe "outputs/amazon_es" do
  describe "http client create" do
    require "logstash/outputs/amazon_es"
    require "elasticsearch"

    let(:options) {
      {
        "index" => "my-index",
        "hosts" => "localhost",
        "path" => "some-path"
      }
    }

    let(:eso) {LogStash::Outputs::AmazonES.new(options)}

    let(:manticore_host) {
      eso.client.send(:client).transport.options[:hosts].first
    }

    around(:each) do |block|
      thread = eso.register
      block.call()
      thread.kill()
    end

    describe "with path" do
      it "should properly create a URI with the path" do
        expect(eso.path).to eql(options["path"])
      end


      it "should properly set the path on the HTTP client" do
        expect(manticore_host).to include("/" + options["path"])
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:eso) {
          LogStash::Outputs::AmazonES.new(options.merge("path" => "/some-path/"))
        }

        it "should properly set the path on the HTTP client without adding slashes" do
          expect(manticore_host).to include(options["path"])
        end
      end
    end
  end
end
