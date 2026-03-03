# syntax=docker/dockerfile:1
# check=error=true

# =============================================================================
# Vulcan Multi-Stage Dockerfile
# =============================================================================
# Supports multiple build targets:
#   - development: Full dev environment with all dependencies
#   - production:  Optimized production image (default)
#
# Build commands:
#   docker build -t vulcan:dev --target development .
#   docker build -t vulcan:prod --target production .
#
# Multi-arch support (amd64/arm64):
#   docker buildx build --platform linux/amd64,linux/arm64 --target production -t vulcan:prod .
# =============================================================================

# Make sure versions match .ruby-version
ARG RUBY_VERSION=3.4.8
ARG NODE_VERSION=22.16.0

# =============================================================================
# BASE STAGE - Common foundation for all stages
# =============================================================================
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Install base packages including jemalloc for better memory management
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      libjemalloc2 \
      libpq5 \
      libvips42 \
      libyaml-0-2 \
      postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install custom SSL certificates if provided
COPY certs/ /usr/local/share/ca-certificates/custom/
WORKDIR /usr/local/share/ca-certificates/custom
RUN for cert in ./*.pem ./*.cer; do \
      [ -f "$cert" ] && mv "$cert" "${cert%.*}.crt" || true; \
    done && \
    if ls ./*.crt 2>/dev/null | grep -q .; then \
      update-ca-certificates; \
    fi && \
    rm -rf /usr/local/share/ca-certificates/custom/README.md
WORKDIR /rails

# Common environment for all stages
ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    MALLOC_ARENA_MAX="2" \
    NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt" \
    BUNDLE_PATH="/usr/local/bundle"

# =============================================================================
# BUILD-BASE STAGE - Build tools + Node.js (shared by build and development)
# =============================================================================
FROM base AS build-base

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      gnupg \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      zlib1g-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js LTS using official binaries
ARG NODE_VERSION
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz && \
    corepack enable

# =============================================================================
# BUILD STAGE - Compile gems and assets (for production)
# =============================================================================
FROM build-base AS build

# Build stage environment - production mode for asset compilation
# Note: NODE_ENV is NOT set here because yarn skips devDependencies when NODE_ENV=production
# and we need devDependencies (esbuild, sass-plugin, etc.) to build assets
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test"

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules (including dev dependencies needed for asset build)
COPY package.json yarn.lock esbuild.config.js ./
RUN yarn install --frozen-lockfile --production=false --network-timeout 100000

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompile Rails assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Remove dev/test files, node_modules, and source maps to reduce image size
# Note: app/assets/ can be deleted - assets:precompile copies to public/assets/
RUN rm -rf node_modules tmp/cache app/assets vendor/assets spec test .git && \
    find public/assets -name '*.map' -delete 2>/dev/null || true

# =============================================================================
# DEVELOPMENT STAGE - Full development environment
# =============================================================================
FROM build-base AS development

# Additional dev tools (build deps + Node.js already in build-base)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      vim \
      less && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Development environment
ENV RAILS_ENV="development" \
    BUNDLE_WITHOUT="" \
    BUNDLE_DEPLOYMENT="0"

# Install all gems including dev/test
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install node modules
COPY package.json yarn.lock esbuild.config.js ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails .

USER 1000:1000

EXPOSE 3000

# Development server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# =============================================================================
# PRODUCTION STAGE - Optimized for deployment (default)
# =============================================================================
FROM base AS production

# Production environment — infrastructure only (12-factor: config via env vars at deploy time)
# App config defaults live in config/vulcan.default.yml, database.yml, and production.rb.
# Override at deploy time via docker-compose environment:, env_file:, or .env.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

# Create non-root user before COPY --chown (avoids extra chown layer)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Copy built artifacts from build stage with correct ownership
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

# Ensure writable directories exist
RUN mkdir -p db log storage tmp

USER 1000:1000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

EXPOSE 3000

# Entrypoint handles db:prepare on server start (Rails standard pattern)
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Production server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
