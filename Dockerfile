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
#   docker buildx bake production
#   docker buildx bake dev
#
# Or use the CLI:
#   vulcan build
#   vulcan build --target development
# =============================================================================

# Make sure versions match .ruby-version and .nvmrc
ARG RUBY_VERSION=3.4.7
ARG NODE_VERSION=24.11.1
ARG BUNDLER_VERSION=2.6.5

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
      libvips \
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
# BUILD STAGE - Compile gems and assets
# =============================================================================
FROM base AS build

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

# Install Node.js LTS and pnpm using official binaries
ARG NODE_VERSION
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz && \
    npm install -g pnpm@10

# Build stage environment - production mode for asset compilation
ARG BUNDLER_VERSION
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test"

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules (including dev dependencies for build)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml vite.config.ts ./
COPY config/vite.json ./config/
RUN pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Build Vite assets for production (includes gzip/brotli compression)
RUN bin/vite build

# Precompile Rails assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Remove dev/test files and node_modules BEFORE copying to production stage
# This is critical - doing it here reduces the final image size significantly
RUN rm -rf node_modules tmp/cache app/assets vendor/assets spec test .git

# =============================================================================
# DEVELOPMENT STAGE - Full development environment
# =============================================================================
FROM base AS development

# Install development packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      gnupg \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      zlib1g-dev \
      vim \
      less && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js and pnpm
ARG NODE_VERSION
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz && \
    npm install -g pnpm@10

# Development environment
ENV RAILS_ENV="development" \
    BUNDLE_WITHOUT="" \
    BUNDLE_DEPLOYMENT="0"

# Install all gems including dev/test
ARG BUNDLER_VERSION
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v ${BUNDLER_VERSION} && \
    bundle install

# Install node modules
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml vite.config.ts ./
COPY config/vite.json ./config/
RUN pnpm install

# Copy application code
COPY . .

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails .

USER 1000:1000

# Port configuration
ARG WEB_PORT=3000
ARG PROMETHEUS_PORT=9394
EXPOSE ${WEB_PORT} ${PROMETHEUS_PORT}

# Development server with file watching
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# =============================================================================
# PRODUCTION STAGE - Optimized for deployment (default)
# =============================================================================
FROM base AS production

# Production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

# Copy built artifacts from build stage
# Note: cleanup already done in build stage to minimize copy size
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Create non-root user and set ownership
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp public

USER 1000:1000

# Port configuration
ARG WEB_PORT=3000
ARG PROMETHEUS_PORT=9394

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${WEB_PORT}/up || exit 1

EXPOSE ${WEB_PORT} ${PROMETHEUS_PORT}

# Production server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
