FROM ruby:2.4.4

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs sqlite

ENV RAILS_ROOT /var/www/vulcan

RUN mkdir -p $RAILS_ROOT/tmp/pids

WORKDIR $RAILS_ROOT

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN gem install bundler && bundle install --jobs 20 --retry 5

ENV RAILS_ENV=production
#ENV RAILS_RELATIVE_URL_ROOT=/vulcan
ENV RAILS_SERVE_STATIC_FILES=true

COPY . .

# Use a random key base
RUN bash -c "SECRET_KEY_BASE=$(openssl rand -hex 64) RAILS_ENV=$RAILS_ENV RAILS_RELATIVE_URL_ROOT=$RAILS_RELATIVE_URL_ROOT bundle exec rake assets:precompile"

EXPOSE 3000

ENTRYPOINT ["bundle", "exec"]
