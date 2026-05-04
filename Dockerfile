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

ARG RUBY_VERSION=3.4.9
ARG NODE_VERSION=24.14.0

# =============================================================================
# BASE STAGE - Common foundation for all stages
# =============================================================================
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.7 AS base

USER 0
RUN mkdir -p /rails /usr/local/bundle && \
    chown -R 1001:0 /rails /usr/local/bundle && \
    chmod -R g=u /rails /usr/local/bundle
WORKDIR /rails

# Install base packages.
# libvips removed — image_processing gem is commented out and ActiveStorage
# is not used for file attachments. Install only the runtime packages here;
# Ruby itself is compiled in build-base and copied into the final image.
# check if can del postgres image later on
RUN microdnf install -y \
      ca-certificates \
      curl \
      findutils \
      glibc-langpack-en \
      libffi \
      libyaml \
      openssl \
      postgresql \
      readline \
      shadow-utils \
      tar \
      xz \
      zlib && \
    microdnf clean all

# Install custom SSL certificates if provided (single layer)
COPY certs/ /etc/pki/ca-trust/source/anchors/
RUN  update-ca-trust && \
     rm -f /etc/pki/ca-trust/source/anchors/*

# Common environment for all stages
ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    MALLOC_ARENA_MAX="2" \
    NODE_EXTRA_CA_CERTS="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" \
    BUNDLE_USER_HOME="/usr/local/bundle" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_BIN="/usr/local/bundle/bin" \
    GEM_HOME="/usr/local/bundle" \
    PATH="/usr/local/bundle/bin:/usr/local/bin:${PATH}"

USER 1001

# =============================================================================
# BUILD-BASE STAGE - Build tools + Node.js (shared by build and development)
# =============================================================================
FROM base AS build-base

ARG RUBY_VERSION

USER 0

# Install packages needed to compile Ruby, build gems, and install node modules
RUN microdnf install -y \
      autoconf \
      bison \
      findutils \
      gcc \
      gcc-c++ \
      gmp-devel \
      libffi-devel \
      libyaml-devel \
      make \
      openssl-devel \
      patch \
      perl \
      postgresql-devel \
      readline-devel \
      rust \
      tar \
      xz \
      xz-devel \
      zlib-devel && \
    microdnf clean all && \
    curl -fsSL https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz -o /tmp/ruby.tar.gz && \
    tar -xzf /tmp/ruby.tar.gz -C /tmp && \
    cd /tmp/ruby-${RUBY_VERSION} && \
    ./configure --prefix=/usr/local \
      --disable-install-doc \
      --enable-yjit && \
    make -j"$(nproc)" && \
    make install && \
    gem update --system && \
    gem install bundler && \
    rm -rf /tmp/ruby-${RUBY_VERSION} /tmp/ruby.tar.gz && \
    ruby --version && \
    bundle --version

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
RUN bundle install && \
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

USER 0

# Additional dev tools (build deps + Node.js already in build-base)
RUN dnf install -y \
      vim-enhanced && \
    dnf clean all && \
    rm -rf /var/cache/dnf

USER 1001

# Development environment
ENV RAILS_ENV="development" \
    BUNDLE_WITHOUT="" \
    BUNDLE_DEPLOYMENT="0"

# Install all gems including dev/test
COPY --chown=1001:0 Gemfile Gemfile.lock ./
RUN bundle install

# Install node modules
COPY --chown=1001:0 package.json yarn.lock esbuild.config.js ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY --chown=1001:0 . .

USER 0

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

USER 0

# Production environment — infrastructure only (12-factor: config via env vars at deploy time)
# App config defaults live in config/vulcan.default.yml, database.yml, and production.rb.
# Override at deploy time via docker-compose environment:, env_file:, or .env.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

# Copy built artifacts from build stage
COPY --from=build /usr/local /usr/local
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
