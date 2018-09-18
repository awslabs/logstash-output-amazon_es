require "logstash/devutils/rspec/spec_helper"
require 'manticore'
require 'elasticsearch'

# by default exclude secure_integration tests unless requested
# normal integration specs are already excluded by devutils' spec helper
RSpec.configure do |config|
   config.filter_run_excluding config.exclusion_filter.add(:secure_integration => true)
end

module ESHelper
  def get_host_port
    "127.0.0.1"
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port])
  end

  def self.es_version
    RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
  end

  def self.es_version_satisfies?(*requirement)
    es_version = RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
    if es_version.nil?
      puts "Info: ES_VERSION environment or 'es_version' tag wasn't set. Returning false to all `es_version_satisfies?` call."
      return false
    end
    es_release_version = Gem::Version.new(es_version).release
    Gem::Requirement.new(requirement).satisfied_by?(es_release_version)
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
