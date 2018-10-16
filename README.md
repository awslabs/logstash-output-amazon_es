# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

## License

This library is licensed under Apache License 2.0.

## Compatibility

The following table shows the versions of logstash and logstash-output-amazon_es Plugin was built with.

|  logstash-output-amazon_es | Logstash |
| ------------- | ------------- |
| 6.0.0  | <6.0.0  |
| 6.4.0  | >6.0.0  |

## Configuration for Amazon Elasticsearch Output Plugin

To run the Logstash Output Amazon Elasticsearch plugin, simply add a configuration following the below documentation.

An example configuration:

```
output {
    amazon_es {
        hosts => ["foo.us-east-1.es.amazonaws.com"]
        region => "us-east-1"
        # aws_access_key_id and aws_secret_access_key are optional if instance profile is configured
        aws_access_key_id => 'ACCESS_KEY'
        aws_secret_access_key => 'SECRET_KEY'
        index => "production-logs-%{+YYYY.MM.dd}"
    }
}
```

### Required Parameters

- hosts (array of string) - the Amazon Elasticsearch Service domain endpoint (e.g. `["foo.us-east-1.es.amazonaws.com"]`)
- region (string, :default => "us-east-1") - region where the domain is located

### Optional Parameters

- Credential parameters:

  * aws_access_key_id, :validate => :string - optional AWS access key
  * aws_secret_access_key, :validate => :string - optional AWS secret key

	 The credential resolution logic can be described as follows:

	 - User passed `aws_access_key_id` and `aws_secret_access_key` in `amazon_es` configuration
	 - Environment variables - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (RECOMMENDED since they are recognized by all the AWS SDKs and CLI except for .NET), or `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` (only recognized by Java SDK)
	 - Credential profiles file at the default location (`~/.aws/credentials`) shared by all AWS SDKs and the AWS CLI
	 - Instance profile credentials delivered through the Amazon EC2 metadata service

- template (path) - You can set the path to your own template here, if you so desire. If not set, the included template will be used.
- template_name (string, default => "logstash") - defines how the template is named inside Elasticsearch
- port (string, default 443) - Amazon Elasticsearch Service listens on port 443 for HTTPS (default) and port 80 for HTTP. Tweak this value for a custom proxy.
- protocol (string, default https) - The protocol used to connect to the Amazon Elasticsearch Service

After 6.4.0, users can't set batch size in this output plugin config. However, users can still set batch size in logstash.yml file.
## Developing

### 1. Plugin Development and Testing

#### Code

1. To get started, you'll need JRuby with the Bundler gem installed.

2. Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. [Example plugins](https://github.com/logstash-plugins?query=example) exist.

3. Install dependencies:

   ```sh
   bundle install
   ```

#### Test

1. Update your dependencies:

   ```sh
   bundle install
   ```

2. Run unit tests:

   ```sh
   bundle exec rspec
   ```

### 2. Running your unpublished plugin in Logstash

#### 2.1 Run in a local Logstash clone

1. Edit Logstash `Gemfile` and add the local plugin path, for example:

   ```ruby
   gem "logstash-filter-awesome", :path => "/your/local/logstash-filter-awesome"
   ```

2. Install the plugin:

   ```sh
   # Logstash 2.3 and higher
   bin/logstash-plugin install --no-verify

   # Prior to Logstash 2.3
   bin/plugin install --no-verify
   ```

3. Run Logstash with your plugin:

   ```sh
   bin/logstash -e 'filter {awesome {}}'
   ```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply re-run Logstash.

#### 2.2 Run in an installed Logstash

Before build your `Gemfile`, please make sure use JRuby. Here is how you can know your local Ruby version:

```sh
rvm list
```

Please make sure you current using JRuby. Here is how you can change to JRuby

```sh
rvm jruby
```

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory. You can also build the gem and install it using:

1. Build your plugin gem:

   ```sh
   gem build logstash-filter-awesome.gemspec
   ```

2. Install the plugin from the Logstash home:

   ```sh
   # Logstash 2.3 and higher
   bin/logstash-plugin install --no-verify

   # Prior to Logstash 2.3
   bin/plugin install --no-verify
   ```

3. Start Logstash and test the plugin.

## Old version support

If you want to use old version of logstash-output-amazon_es, you can install with this:  
```sh
bin/logstash-plugin install logstash-output-amazon_es -v 2.0.0
```



## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, and complaints.
