FROM ruby:3.3.9

# Install custom SSL certificates if provided
# Users can place .crt, .pem, or .cer files in the certs/ directory
# These will be added to the system certificate store
COPY certs/ /usr/local/share/ca-certificates/custom/
WORKDIR /usr/local/share/ca-certificates/custom
RUN # Convert .pem and .cer files to .crt extension (required by update-ca-certificates) \
    for cert in ./*.pem; do \
      [ -f "$cert" ] && cp "$cert" "${cert%.pem}.crt" || true; \
    done && \
    for cert in ./*.cer; do \
      [ -f "$cert" ] && cp "$cert" "${cert%.cer}.crt" || true; \
    done && \
    # Check if we have any certificates to install
    if ls ./*.crt ./*.pem 2>/dev/null | grep -q .; then \
      echo "Installing custom certificates..." && \
      update-ca-certificates; \
    else \
      echo "No custom certificates found"; \
    fi

# Reset working directory back to root
WORKDIR /

# Set Node to use system certificates for all subsequent commands
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Install Node.js and Yarn
RUN curl -sS https://deb.nodesource.com/setup_22.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -qq && apt-get install -y build-essential nodejs yarn && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV APP_HOME=/app
ENV RAILS_ENV=production
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

RUN gem install bundler:2.3.27
COPY Gemfile* $APP_HOME/
RUN bundle install --without development test

COPY . $APP_HOME
# Install all dependencies (including dev) for build and build assets
# Don't set NODE_ENV during the build to ensure all modules are available
RUN yarn install --frozen-lockfile && \
    SECRET_KEY_BASE=dummyvalue bundle exec rake assets:precompile
# Remove dev dependencies after build to reduce image size
RUN yarn install --production --ignore-scripts --prefer-offline

# Now set NODE_ENV for runtime
ENV NODE_ENV=production

RUN chown -R 1000:2000 /app
USER 1000

CMD ["rails","server","-b","0.0.0.0"]
