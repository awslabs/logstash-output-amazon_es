require "logstash/devutils/rspec/spec_helper"
require "ftw"
require "logstash/plugin"
require "logstash/json"
require "stud/try"
require "longshoreman"

CONTAINER_NAME = "logstash-output-amazon-es-#{rand(999).to_s}"
CONTAINER_IMAGE = "elasticsearch"
CONTAINER_TAG = "1.6"

DOCKER_INTEGRATION = ENV["DOCKER_INTEGRATION"]

module ESHelper
  def get_host
    DOCKER_INTEGRATION ? Longshoreman.new.get_host_ip : "127.0.0.1"
  end

  def get_port
    return 9200 unless DOCKER_INTEGRATION

    container = Longshoreman::Container.new
    container.get(CONTAINER_NAME)
    container.rport(9200)
  end

  def get_client
    Elasticsearch::Client.new(:host => "#{get_host}:#{get_port}")
  end
end


RSpec.configure do |config|
  config.include ESHelper


  if DOCKER_INTEGRATION
    # this :all hook gets run before every describe block that is tagged with :integration => true.
    config.before(:all, :integration => true) do


      # check if container exists already before creating new one.
      begin
        ls = Longshoreman::new
        ls.container.get(CONTAINER_NAME)
      rescue Docker::Error::NotFoundError
        Longshoreman.new("#{CONTAINER_IMAGE}:#{CONTAINER_TAG}", CONTAINER_NAME)
        # TODO(talevy): verify ES is running instead of static timeout
        sleep 10
      end
    end

    # we want to do a final cleanup after all :integration runs,
    # but we don't want to clean up before the last block.
    # This is a final blind check to see if the ES docker container is running and
    # needs to be cleaned up. If no container can be found and/or docker is not
    # running on the system, we do nothing.
    config.after(:suite) do
      # only cleanup docker container if system has docker and the container is running
      begin
        ls = Longshoreman::new
        ls.container.get(CONTAINER_NAME)
        ls.cleanup
      rescue Docker::Error::NotFoundError, Excon::Errors::SocketError
        # do nothing
      end
    end
  end
end
