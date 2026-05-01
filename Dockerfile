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

ARG NODE_VERSION=24.14.0

# =============================================================================
# BASE STAGE - Common foundation for all stages
# =============================================================================
FROM registry.access.redhat.com/ubi9/ruby-33:1 AS base

USER 0
RUN mkdir -p /rails /usr/local/bundle && \
    chown -R 1001:0 /rails /usr/local/bundle && \
    chmod -R g=u /rails /usr/local/bundle
WORKDIR /rails

# Install base packages.
# libvips removed — image_processing gem is commented out and ActiveStorage
# is not used for file attachments. curl, libpq, and libyaml are already
# present in the UBI Ruby base image, so only postgresql is installed here for
# db:prepare.
# check if can del postgres image later on
RUN dnf install -y \
      postgresql && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Install custom SSL certificates if provided (single layer)
COPY certs/ /etc/pki/ca-trust/source/anchors/
RUN  update-ca-trust && \
     rm -f /etc/pki/ca-trust/source/anchors/*

# Common environment for all stages
ENV MALLOC_ARENA_MAX="2" \
    NODE_EXTRA_CA_CERTS="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" \
    BUNDLE_USER_HOME="/usr/local/bundle" \
    BUNDLE_PATH="/usr/local/bundle"

USER 1001

# =============================================================================
# BUILD-BASE STAGE - Build tools + Node.js (shared by build and development)
# =============================================================================
FROM base AS build-base

USER 0

# Install packages needed to build gems and node modules
RUN dnf install -y \
      postgresql-devel \
      libyaml-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Install Node.js LTS using official binaries
ARG NODE_VERSION
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    echo "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz && \
    corepack enable

USER 1001

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

COPY --chown=1001:0 Gemfile Gemfile.lock ./
RUN bundle config set frozen false && bundle install && \
    ls -lah /usr/local/bundle/ruby/3.3.0/extensions/x86_64-linux/3.3.0/ox-2.14.23/ox.so && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules (including dev dependencies needed for asset build)
COPY --chown=1001:0 package.json yarn.lock esbuild.config.js ./
RUN yarn install --frozen-lockfile --production=false --network-timeout 100000

# Copy application code
COPY --chown=1001:0 . .

RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -rf \
    node_modules \
    tmp/cache \
    app/assets \
    vendor/assets \
    spec \
    test \
    .git \
    docs \
    .node-version \
    .nvmrc \
    .browserslistrc \
    yarn.lock \
    package.json \
    esbuild.config.js && \
    find public/assets -name '*.map' -delete 2>/dev/null || true && \
    # Strip gem build artifacts and cached .o/.so files
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache && \
    find "${BUNDLE_PATH}" -name '*.o' -o -name '*.c' -o -name '*.h' | xargs rm -f 2>/dev/null || true

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

USER root

# Production environment — infrastructure only (12-factor: config via env vars at deploy time)
# App config defaults live in config/vulcan.default.yml, database.yml, and production.rb.
# Override at deploy time via docker-compose environment:, env_file:, or .env.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

# Copy built artifacts from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chmod=755 /rails /rails

# Create non-root user, writable dirs, and strip bundle artifacts in one layer
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

USER 1000:1000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

EXPOSE 3000

# Entrypoint handles db:prepare on server start (Rails standard pattern)
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Production server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
