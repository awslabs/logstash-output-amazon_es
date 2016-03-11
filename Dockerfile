# Source: https://github.com/cpuguy83/docker-jruby/blob/1f289ddb5d77c41b9f096384bdc412efa76e3d63/1.7/jre/Dockerfile

FROM java:8-jre

RUN apt-get update && apt-get install -y libc6-dev --no-install-recommends && rm -rf /var/lib/apt/lists/*

ENV JRUBY_VERSION 1.7.22
ENV JRUBY_SHA1 6b9e310a04ad8173d0d6dbe299da04c0ef85fc15
RUN mkdir /opt/jruby \
  && curl -fSL https://s3.amazonaws.com/jruby.org/downloads/${JRUBY_VERSION}/jruby-bin-${JRUBY_VERSION}.tar.gz -o /tmp/jruby.tar.gz \
  && echo "$JRUBY_SHA1 /tmp/jruby.tar.gz" | sha1sum -c - \
  && tar -zx --strip-components=1 -f /tmp/jruby.tar.gz -C /opt/jruby \
  && rm /tmp/jruby.tar.gz \
  && update-alternatives --install /usr/local/bin/ruby ruby /opt/jruby/bin/jruby 1
ENV PATH /opt/jruby/bin:$PATH

RUN echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc

ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$PATH
RUN gem install bundler \
	&& bundle config --global path "$GEM_HOME" \
	&& bundle config --global bin "$GEM_HOME/bin"

# don't create ".bundle" in all our apps
ENV BUNDLE_APP_CONFIG $GEM_HOME

RUN mkdir /var/build_dir

# The contents of the volume are the actual build sources as defined in docker-compose.yml ('-v .:/var/build').
VOLUME /var/build_dir 

WORKDIR /var/build_dir

# The build tool.
ENTRYPOINT ["gem"]

# Setting default args for entrypoint command.
# Running the container should result in a binary inside the host-mounted volume named 'logstash-output-amazon_es-<VERSION>-java.gem'.
# Where <VERSION> is defined as value of 's.version' in logstash-output-amazon_es.gemspec file.
CMD [ "build", "logstash-output-amazon_es.gemspec" ]
