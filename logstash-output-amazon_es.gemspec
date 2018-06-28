Gem::Specification.new do |s|

  s.name            = 'logstash-output-amazon_es'
  s.version         = '2.0.0'
  s.licenses        = ['apache-2.0']
  s.summary         = "Logstash Output to Amazon Elasticsearch Service"
  s.description     = "Output events to Amazon Elasticsearch Service with V4 signing"
  s.authors         = ["Amazon"]
  s.email           = 'feedback-prod-elasticsearch@amazon.com'
  s.homepage        = "http://logstash.net/"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency 'concurrent-ruby'
  s.add_runtime_dependency 'elasticsearch', '>= 1.0.10', '<= 6.2.0'
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency 'cabin', ['~> 0.6']
  s.add_runtime_dependency 'logstash-core-plugin-api', '>= 1.60', '<= 2.99'
  s.add_runtime_dependency 'aws-sdk', '>= 2.3.22', '~> 2'
  s.add_runtime_dependency "faraday", '~> 0.9.1'
  s.add_runtime_dependency "faraday_middleware", '~> 0.10.0'

  s.add_development_dependency 'addressable', '< 2.5.0'
  s.add_development_dependency 'ftw', '~> 0.0.42'
  s.add_development_dependency 'logstash-input-generator'

  if RUBY_PLATFORM == 'java'
    s.platform = RUBY_PLATFORM
    s.add_runtime_dependency "manticore", '>= 0.5.2', '< 1.0.0'
  end

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'longshoreman'
end
