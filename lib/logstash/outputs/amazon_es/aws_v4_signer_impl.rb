require 'aws-sdk-core'
require 'faraday'


class AwsV4Signer < Faraday::Middleware
  class Request
    def initialize(env)
      @env = env
    end

    def headers
      @env.request_headers
    end

    def set_header(header)
      @env.request_headers = header
    end

    def body
      @env.body || ''
    end

    def endpoint
      @env.url
    end

    def http_method
      @env.method.to_s.upcase
    end
  end

  def signer
    credentials = @options.fetch(:credentials)
    service_name = @options.fetch(:service_name)
    region = @options.fetch(:region)
    Aws::Signers::V4.new(credentials, service_name, region)
  end

 def initialize(app, options = nil)
    super(app)
    @options = options
    @net_http = app.is_a?(Faraday::Adapter::NetHttp)
  end

  def call(env)
    normalize_for_net_http!(env)
    req = Request.new(env)
    signer().sign(req)
    @app.call(env)
  end

  private
  def normalize_for_net_http!(env)
    return unless @net_http

    if Net::HTTP::HAVE_ZLIB
      env.request_headers['Accept-Encoding'] ||= 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'
    end

    env.request_headers['Accept'] ||= '*/*'
  end
end
