# Logstash Output Plugin


This plugin is now in maintenance mode. We will supply bug fixes and security patches for v7.2.X, older versions are no longer supported. This change is because the OpenSearch Project created a new Logstash output plugin
[logstash-output-opensearch](https://github.com/opensearch-project/logstash-output-opensearch) which ships events from
Logstash to OpenSearch 1.x and Elasticsearch 7.x clusters, and also supports SigV4 signing. Having similar functionality
plugins can be redundant, so we plan to eventually replace this logstash-output-amazon_es plugin with the logstash-output-opensearch
plugin.

To help you migrate to [logstash-output-opensearch](https://github.com/opensearch-project/logstash-output-opensearch) plugin, please
find below a brief migration guide.

## Migrating to logstash-output-opensearch plugin


This guide provides instructions for existing users of logstash-output-amazon_es plugin to migrate to
logstash-output-opensearch plugin.

### Configuration Changes
* The plugin name will change from `amazon_es` to `opensearch`.
* If using HTTPS this must be explicitly configured because `opensearch` plugin does not default to it like `amazon_es` does:
  * The protocol must be included in `hosts` as `https` (or option `ssl` added with value `true`)
  * `port` must explicitly specified as `443`
* A new parameter `auth_type` will be added to the Config to support SigV4 signing.
* The `region` parameter will move under `auth_type`.
* Credential parameters `aws_access_key_id` and `aws_secret_access_key` will move under `auth_type`.
* The `type` value for `auth_type` for SigV4 signing will be set to `aws_iam`.

For the Logstash configuration provided in [Configuration for Amazon Elasticsearch Service Output Plugin
](#configuration-for-amazon-elasticsearch-service-output-plugin), here's a mapped example configuration for
logstash-output-opensearch plugin:

```
output {
   opensearch {
          hosts => ["https://hostname:port"]
          auth_type => {
              type => 'aws_iam'
              aws_access_key_id => 'ACCESS_KEY'
              aws_secret_access_key => 'SECRET_KEY'
              region => 'us-west-2'
          }
          index  => "logstash-logs-%{+YYYY.MM.dd}"
   }
}
```

### Installation of logstash-output-opensearch plugin
This [Installation Guide](https://opensearch.org/docs/latest/clients/logstash/index/) has instructions on installing the
logstash-output-opensearch plugin in two ways: Linux (ARM64/X64) OR Docker (ARM64/X64).

To install the latest version of logstash-output-opensearch, use the normal Logstash plugin installation command:
```shell
bin/logstash-plugin install logstash-output-opensearch
```

# Using the logstash-output-amazon_es plugin


The remainder of this document is for using or developing the logstash-output-amazon_es plugin.


## Overview

This is a plugin for [Logstash](https://github.com/elastic/logstash) which outputs
to [Amazon OpenSearch Service](https://aws.amazon.com/opensearch-service/)
(successor to Amazon Elasticsearch Service) using
[SigV4 signing](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html).

## License

This library is licensed under Apache License 2.0.

## Compatibility

The following table shows the versions of logstash and logstash-output-amazon_es plugin was built with.

| logstash-output-amazon_es | Logstash |
|---------------------------|----------|
| 6.0.0                     | < 6.0.0  |
| 6.4.2                     | >= 6.0.0 |
| 7.0.1                     | >= 7.0.0 |
| 7.1.0                     | >= 7.0.0 |
| 7.2.0                     | >= 7.0.0 |

Also, logstash-output-amazon_es plugin versions 6.4.0 and newer are tested to be compatible with Elasticsearch 6.5 and greater.

|  logstash-output-amazon_es | Elasticsearch |
| ------------- |----------|
| 6.4.0+  | 6.5+     |


## Installation

To install the latest version, use the normal Logstash plugin script.

```sh
bin/logstash-plugin install logstash-output-amazon_es
```

If you want to use old version of logstash-output-amazon_es, you can use the `--version`
flag to specify the version. For example:

```sh
bin/logstash-plugin install --version 6.4.2 logstash-output-amazon_es
```

Starting in 7.2.0, the aws sdk version is bumped to v3. In order for all other AWS plugins to work together, please remove pre-installed plugins and install logstash-integration-aws plugin as follows. See also https://github.com/logstash-plugins/logstash-mixin-aws/issues/38
```
# Remove existing logstash aws plugins and install logstash-integration-aws to keep sdk dependency the same
# https://github.com/logstash-plugins/logstash-mixin-aws/issues/38
/usr/share/logstash/bin/logstash-plugin remove logstash-input-s3
/usr/share/logstash/bin/logstash-plugin remove logstash-input-sqs
/usr/share/logstash/bin/logstash-plugin remove logstash-output-s3
/usr/share/logstash/bin/logstash-plugin remove logstash-output-sns
/usr/share/logstash/bin/logstash-plugin remove logstash-output-sqs
/usr/share/logstash/bin/logstash-plugin remove logstash-output-cloudwatch

/usr/share/logstash/bin/logstash-plugin install --version 0.1.0.pre logstash-integration-aws
bin/logstash-plugin install --version 7.2.0 logstash-output-amazon_es
```

## Configuration for Amazon Elasticsearch Service Output Plugin

To run the Logstash Output Amazon Elasticsearch Service plugin, simply add a configuration following the below documentation.

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
- max_bulk_bytes - The max size for a bulk request in bytes. Default is 20MB. It is recommended not to change this value unless needed. For guidance on changing this value, please consult the table for network limits for your instance type: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-limits.html#network-limits

After 6.4.0, users can't set batch size in this output plugin config. However, users can still set batch size in logstash.yml file.

### Advanced Optional Parameters

Starting logstash-output-amazon_es v7.1.0, we have introduced the following optional parameters to resolve specific use cases:

- service_name (string, default => "es") - Users can define any service name to which the plugin will send a SigV4 signed request
- skip_healthcheck (boolean, default => false) - Boolean to skip healthcheck API and set the major ES version to 7
- skip_template_installation (boolean, default => false) -  Boolean to allow users to skip installing templates in usecases that don't require them

## Developing

### 1. Prerequisites
To get started, you can install JRuby with the Bundler gem using [RVM](https://rvm.io/rvm/install)

```shell
rvm install jruby-9.2.5.0
```

### 2. Plugin Development and Testing

#### Code

1. Verify JRuby is already installed

   ```sh
   jruby -v
   ```


2. Install dependencies:

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

### 3. Running your unpublished plugin in Logstash

#### 3.1 Run in a local Logstash clone

1. Edit Logstash `Gemfile` and add the local plugin path, for example:

   ```ruby
   gem "logstash-output-amazon_es", :path => "/your/local/logstash-output-amazon_es"
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
   bin/logstash -e 'output {amazon_es {}}'
   ```

At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply re-run Logstash.

#### 3.2 Run in an installed Logstash

Before build your `Gemfile`, please make sure use JRuby. Here is how you can know your local Ruby version:

```sh
rvm list
```

Please make sure you current using JRuby. Here is how you can change to JRuby

```sh
rvm jruby-9.2.5.0
```

You can use the same **3.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory. You can also build the gem and install it using:

1. Build your plugin gem:

   ```sh
   gem build logstash-output-amazon_es.gemspec
   ```

2. Install the plugin from the Logstash home. Please be sure to check the version number against the actual Gem file. Run:

   ```sh
   bin/logstash-plugin install /your/local/logstash-output-amazon_es/logstash-output-amazon_es-7.0.1-java.gem
   ```

3. Start Logstash and test the plugin.


## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, and complaints.
