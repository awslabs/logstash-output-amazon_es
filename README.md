# Logstash Plugin

[![Travis Build Status](https://travis-ci.org/logstash-plugins/logstash-output-elasticsearch.svg)](https://travis-ci.org/logstash-plugins/logstash-output-elasticsearch)

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Configuration for Amazon Elasticsearch Output plugin

To run the Logstash output Amazon Elasticsearch plugin simply add a configuration following the below documentation.

An example configuration:

	output {
	    amazon_es {
	        hosts => ["foo.us-east-1.es.amazonaws.com"]
	        region => "us-east-1"
	        # aws_access_key_id, aws_secret_access_key optional if instance profile is configured
	        aws_access_key_id => 'ACCESS_KEY'
	        aws_secret_access_key => 'SECRET_KEY'
	        index => "production-logs-%{+YYYY.MM.dd}"
            }
        }

* Required Parameters
	* hosts (array of string) - Amazon Elasticsearch domain endpoint. eg ["foo.us-east-1.es.amazonaws.com"]
    * region (string, :default => "us-east-1") - region where the domain is located

* Optional Parameters
	* Credential parameters
	    * aws_access_key_id, :validate => :string - Optional AWS Access key
		* aws_secret_access_key, :validate => :string - Optional AWS Secret Key  
		    The credential resolution logic can be described as follows:
		    - User passed aws_access_key_id and aws_secret_access_key in aes configuration
		    - Environment Variables - AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
		     (RECOMMENDED since they are recognized by all the AWS SDKs and CLI except for .NET),
		     or AWS_ACCESS_KEY and AWS_SECRET_KEY (only recognized by Java SDK)
		    - Credential profiles file at the default location (~/.aws/credentials) shared by all AWS SDKs and the AWS CLI
		    - Instance profile credentials delivered through the Amazon EC2 metadata service
	* template (path) - You can set the path to your own template here, if you so desire. If not set, the included template will be used.
	* template_name (string, default => "logstash") - defines how the template is named inside Elasticsearch
	* port (string, default 443) - Amazon Elasticsearch Service listens on port 443 - https (default) and 80 - http. Tweak this for custom proxy.
	* protocol (string, default https) - The protocol used to connect to the Amazon Elasticsearch Service

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elastic/docs#asciidoc-guide

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run unit tests

```sh
bundle exec rspec
```


### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone

- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-filter-awesome", :path => "/your/local/logstash-filter-awesome"
```
- Install plugin
```sh
# Logstash 2.3 and higher
bin/logstash-plugin install --no-verify

# Prior to Logstash 2.3
bin/plugin install --no-verify

```
- Run Logstash with your plugin
```sh
bin/logstash -e 'filter {awesome {}}'
```
At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
gem build logstash-filter-awesome.gemspec
```
- Install the plugin from the Logstash home
```sh
# Logstash 2.3 and higher
bin/logstash-plugin install --no-verify

# Prior to Logstash 2.3
bin/plugin install --no-verify

```
- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.
