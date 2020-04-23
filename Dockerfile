FROM ruby:2.6.6-alpine as Builder

ENV RAILS_ROOT /var/www/vulcan

# Deploy production server to container
ENV RAILS_ENV=production

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY Gemfile Gemfile.lock ./

# Ensure we never install docs
RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc

RUN apk --no-cache --update add build-base \
    libc-dev libxml2-dev imagemagick6 imagemagick6-dev pkgconf nodejs postgresql-dev tzdata

RUN gem install bundler && bundle install --deployment --without development test -j4 --retry 3

COPY . .

RUN rm -rf tmp/cache spec vendor/bundle/ruby/*/cache && find vendor/bundle/ruby/*/gems/ -name "*.c" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.o" -delete

# The container above is only used for building. Once the source code is built we copy
# the required artifacts out of the build above and put them in a clean container.
# This allows our image size to be much smaller.
FROM ruby:2.6.6-alpine

ENV RAILS_ROOT /var/www/vulcan

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

COPY --from=Builder $RAILS_ROOT $RAILS_ROOT

# It is necessary to re-run bundle install since the /usr/local/bundle/config file is missing on the 2nd container.
# By running bundle install that file is created and bundler begins working correctly.
RUN apk --no-cache --update add nodejs imagemagick6 postgresql-dev tzdata && gem install bundler && \
    bundle install --deployment --without development test

EXPOSE 3000

ENTRYPOINT ["bundle", "exec"]

CMD ["rails", "server", "-p", "3000", "-b", "0.0.0.0"]
