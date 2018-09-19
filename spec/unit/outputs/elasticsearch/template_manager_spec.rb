require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/amazon_es/http_client"
require "java"
require "json"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  describe ".default_template_path" do
    context "amazon_es 1.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(1)).to match(/elasticsearch-template-es2x.json/)
      end
    end
    context "amazon_es 2.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(2)).to match(/elasticsearch-template-es2x.json/)
      end
    end
    context "amazon_es 5.x" do
      it "chooses the 5x template" do
        expect(described_class.default_template_path(5)).to match(/elasticsearch-template-es5x.json/)
      end
    end
  end
end
