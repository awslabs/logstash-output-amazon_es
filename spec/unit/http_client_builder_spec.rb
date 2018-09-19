require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/amazon_es"
require "logstash/outputs/amazon_es/http_client"
require "logstash/outputs/amazon_es/http_client_builder"

describe LogStash::Outputs::ElasticSearch::HttpClientBuilder do
  describe "auth setup with url encodable passwords" do
    let(:klass) { LogStash::Outputs::ElasticSearch::HttpClientBuilder }
    let(:user) { "foo@bar"}
    let(:password) {"baz@blah" }
    let(:password_secured) do
      secured = double("password")
      allow(secured).to receive(:value).and_return(password)
      secured
    end
    let(:options) { {"user" => user, "password" => password} }
    let(:logger) { mock("logger") }
    let(:auth_setup) { klass.setup_basic_auth(double("logger"), {"user" => user, "password" => password_secured}) }

    it "should return the user escaped" do
      expect(auth_setup[:user]).to eql(CGI.escape(user))
    end

    it "should return the password escaped" do
      expect(auth_setup[:password]).to eql(CGI.escape(password))
    end
  end

  describe "customizing action paths" do
    let(:hosts) { [ ::LogStash::Util::SafeURI.new("http://localhost:9200") ] }
    let(:options) { {"hosts" => hosts ,
                     "protocol" => "http",
                     "port" => 9200,
                     "aws_access_key_id" => "AAAAAAAAAAAAAAAAAAAA",
                     "aws_secret_access_key" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"} }
    let(:logger) { double("logger") }
    before :each do
      [:debug, :debug?, :info?, :info, :warn].each do |level|
        allow(logger).to receive(level)
      end
    end

    describe "healthcheck_path" do

      context "when setting bulk_path" do
        let(:bulk_path) { "/meh" }
        let(:options) { super.merge("bulk_path" => bulk_path) }

        context "when using path" do
          let(:options) { super.merge("path" => "/path") }
          it "ignores the path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:bulk_path]).to eq(bulk_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
        context "when not using path" do

          it "uses the bulk_path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:bulk_path]).to eq(bulk_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
      end

      context "when not setting bulk_path" do

        context "when using path" do
          let(:path) { "/meh" }
          let(:options) { super.merge("path" => path) }
          it "sets bulk_path to path+_bulk" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:bulk_path]).to eq("#{path}/_bulk")
            end
            described_class.build(logger, hosts, options)
          end
        end

        context "when not using path" do
          it "sets the bulk_path to _bulk" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:bulk_path]).to eq("/_bulk")
            end
            described_class.build(logger, hosts, options)
          end
        end
      end
    end
    describe "healthcheck_path" do
      context "when setting healthcheck_path" do
        let(:healthcheck_path) { "/meh" }
        let(:options) { super.merge("healthcheck_path" => healthcheck_path) }

        context "when using path" do
          let(:options) { super.merge("path" => "/path") }
          it "ignores the path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:healthcheck_path]).to eq(healthcheck_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
        context "when not using path" do

          it "uses the healthcheck_path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:healthcheck_path]).to eq(healthcheck_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
      end

      context "when not setting healthcheck_path" do

        context "when using path" do
          let(:path) { "/meh" }
          let(:options) { super.merge("path" => path) }
          it "sets healthcheck_path to path" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:healthcheck_path]).to eq(path)
            end
            described_class.build(logger, hosts, options)
          end
        end

        context "when not using path" do
          it "sets the healthcheck_path to root" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:healthcheck_path]).to eq("/")
            end
            described_class.build(logger, hosts, options)
          end
        end
      end
    end
    describe "sniffing_path" do
      context "when setting sniffing_path" do
        let(:sniffing_path) { "/meh" }
        let(:options) { super.merge("sniffing_path" => sniffing_path) }

        context "when using path" do
          let(:options) { super.merge("path" => "/path") }
          it "ignores the path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:sniffing_path]).to eq(sniffing_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
        context "when not using path" do

          it "uses the sniffing_path setting" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:sniffing_path]).to eq(sniffing_path)
            end
            described_class.build(logger, hosts, options)
          end
        end
      end

      context "when not setting sniffing_path" do

        context "when using path" do
          let(:path) { "/meh" }
          let(:options) { super.merge("path" => path) }
          it "sets sniffing_path to path+_nodes/http" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:sniffing_path]).to eq("#{path}/_nodes/http")
            end
            described_class.build(logger, hosts, options)
          end
        end

        context "when not using path" do
          it "sets the sniffing_path to _nodes/http" do
            expect(described_class).to receive(:create_http_client) do |options|
              expect(options[:sniffing_path]).to eq("/_nodes/http")
            end
            described_class.build(logger, hosts, options)
          end
        end
      end
    end
  end
end
