FROM ruby:2.7

RUN curl -sS https://deb.nodesource.com/setup_16.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -y build-essential nodejs yarn

ENV APP_HOME /app
ENV RAILS_ENV production
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN gem install bundler:2.3.10
ADD Gemfile* $APP_HOME/
RUN bundle install --without development test

ADD . $APP_HOME
RUN yarn install --check-files --production
RUN SECRET_KEY_BASE=none NODE_ENV=production bundle exec rake assets:precompile

RUN chown -R 1000:2000 /app
USER 1000

CMD ["rails","server","-b","0.0.0.0"]
