FROM ruby:2.7

RUN curl -sS https://deb.nodesource.com/setup_16.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -y build-essential nodejs yarn

ENV APP_HOME=/app
ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV RACK_ENV=production

# Logging configuration
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_LOG_LEVEL=info

# Asset serving for containerized deployments
ENV RAILS_SERVE_STATIC_FILES=true

# Performance and concurrency settings
ENV RAILS_MAX_THREADS=5
ENV WEB_CONCURRENCY=2

# Memory optimization
ENV MALLOC_ARENA_MAX=2
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN gem install bundler:2.2.32
ADD Gemfile* $APP_HOME/
RUN bundle install --without development test

ADD . $APP_HOME
RUN yarn install --check-files --production
RUN SECRET_KEY_BASE=none NODE_ENV=production bundle exec rake assets:precompile

RUN chown -R 1000:2000 /app
USER 1000

CMD ["rails","server","-b","0.0.0.0"]
