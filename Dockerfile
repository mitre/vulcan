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

ARG RUBY_VERSION=3.4.9
# Upstream SHA256 from https://www.ruby-lang.org/en/news/<release>/
ARG RUBY_SHA256=7bb4d4f5e807cc27251d14d9d6086d182c5b25875191e44ab15b709cd7a7dd9c
ARG BUNDLER_VERSION=2.7.2
ARG NODE_VERSION=24.14.0

# =============================================================================
# BASE STAGE - Common foundation for all stages
# =============================================================================
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.7 AS base

USER 0

# UBI9 ships curl-minimal preinstalled; installing curl would conflict.
# The HEALTHCHECK below relies on curl-minimal.
# libpq (postgresql-libs) is enough at runtime — the pg gem links against
# it but the full postgresql client binaries are only needed at build time.
RUN microdnf update -y && \
    microdnf install -y \
      ca-certificates \
      glibc-langpack-en \
      libffi \
      libpq \
      libyaml \
      openssl \
      readline \
      shadow-utils \
      zlib && \
    microdnf clean all

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

RUN mkdir -p /rails /usr/local/bundle && \
    chown -R 1000:0 /rails /usr/local/bundle && \
    chmod -R g=u /rails /usr/local/bundle
WORKDIR /rails

# Optional custom-CA injection: drop PEM/CRT files into ./certs/ and they
# get imported into the system trust store. The COPY always succeeds because
# certs/ contains at least README.md (tracked in git); the RUN strips it
# before update-ca-trust so only real certs are imported.
COPY certs/ /etc/pki/ca-trust/source/anchors/
RUN rm -f /etc/pki/ca-trust/source/anchors/README.md && \
    update-ca-trust && \
    rm -f /etc/pki/ca-trust/source/anchors/*

ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    MALLOC_ARENA_MAX="2" \
    HOME="/rails" \
    NODE_EXTRA_CA_CERTS="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" \
    BUNDLE_USER_HOME="/usr/local/bundle" \
    BUNDLE_APP_CONFIG="/usr/local/bundle" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_BIN="/usr/local/bundle/bin" \
    GEM_HOME="/usr/local/bundle" \
    PATH="/usr/local/bundle/bin:/usr/local/bin:${PATH}"

USER 1000

# =============================================================================
# BUILD-BASE STAGE - Build tools + Node.js (shared by build and development)
# =============================================================================
FROM base AS build-base

ARG RUBY_VERSION
ARG RUBY_SHA256
ARG BUNDLER_VERSION

USER 0

# rust is required by Ruby's YJIT JIT compiler (--enable-yjit at configure time).
# Not needed by any gem. Only present in build-base; not copied to production.
RUN microdnf update -y && \
    microdnf install -y \
      autoconf \
      bzip2 \
      findutils \
      gcc \
      gcc-c++ \
      git \
      gmp-devel \
      libffi-devel \
      libyaml-devel \
      make \
      openssl-devel \
      patch \
      perl \
      postgresql-devel \
      rust \
      tar \
      xz \
      xz-devel \
      zlib-devel && \
    microdnf clean all
# findutils, tar, xz are kept here (build-time only) and intentionally
# excluded from the base stage — they're not needed at runtime.

RUN curl -fsSL https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz -o /tmp/ruby.tar.gz && \
    echo "${RUBY_SHA256}  /tmp/ruby.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/ruby.tar.gz -C /tmp && \
    cd /tmp/ruby-${RUBY_VERSION} && \
    ./configure --prefix=/usr/local \
      --disable-install-doc \
      --enable-yjit && \
    make -j"$(nproc)" && \
    make install && \
    gem update --system --no-document && \
    gem install bundler:${BUNDLER_VERSION} --no-document && \
    chown -R 1000:0 /usr/local/bundle && \
    chmod -R g=u /usr/local/bundle && \
    cd /tmp && \
    rm -rf /tmp/ruby-${RUBY_VERSION} /tmp/ruby.tar.gz && \
    ruby --version && \
    bundle --version

# jemalloc — UBI doesn't ship it; compile from source for ~20-30% memory savings.
ARG JEMALLOC_VERSION=5.3.0
ARG JEMALLOC_SHA256=2db82d1e7119df3e71b7640219b6dfe84789bc0537983c3b7ac4f7189aecfeaa
RUN curl -fsSL https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2 \
      -o /tmp/jemalloc.tar.bz2 && \
    echo "${JEMALLOC_SHA256}  /tmp/jemalloc.tar.bz2" | sha256sum -c - && \
    tar -xjf /tmp/jemalloc.tar.bz2 -C /tmp && \
    cd /tmp/jemalloc-${JEMALLOC_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf /tmp/jemalloc* && \
    ldconfig

# Node.js is installed to /opt/node, not /usr/local, so the production
# stage's `COPY --from=build /usr/local /usr/local` doesn't drag a Node
# runtime into the final image. Asset compilation is build-stage-only.
ARG NODE_VERSION
ARG TARGETARCH
ENV PATH="/opt/node/bin:${PATH}"
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    NODE_TARBALL="node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}" -o /tmp/node.tar.xz && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o /tmp/node.sha256 && \
    awk -v t="${NODE_TARBALL}" '$2 == t { print $1 "  /tmp/node.tar.xz" }' /tmp/node.sha256 | sha256sum -c - && \
    mkdir -p /opt/node && \
    tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 && \
    rm -f /tmp/node.tar.xz /tmp/node.sha256 && \
    corepack enable

USER 1000

# =============================================================================
# BUILD STAGE - Compile gems and assets (for production)
# =============================================================================
FROM build-base AS build

# NODE_ENV is intentionally NOT set: yarn skips devDependencies when
# NODE_ENV=production, but we need esbuild/sass-plugin to build assets.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test"

COPY --chown=1000:0 --chmod=440 Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache,uid=1000 \
    bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY --chown=1000:0 --chmod=440 package.json yarn.lock esbuild.config.js ./
RUN --mount=type=cache,target=/tmp/.yarn-cache,uid=1000 \
    yarn install --frozen-lockfile --production=false --network-timeout 100000 --cache-folder /tmp/.yarn-cache

COPY --chown=1000:0 . .

RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -rf \
    node_modules \
    .cache \
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
    find "${BUNDLE_PATH}" -name '*.o' -o -name '*.c' -o -name '*.h' | xargs rm -f 2>/dev/null || true && \
    chmod 440 Gemfile Gemfile.lock

# Strip /usr/local build-only artifacts so production COPY gets a lean tree.
# Needs root — /usr/local/share/man, /usr/local/include, etc. are root-owned
# from the Ruby + jemalloc `make install` in build-base.
# Node is already at /opt/node (not copied to production). jemalloc .so stays.
USER 0
RUN rm -rf /usr/local/include \
           /usr/local/share/man /usr/local/share/doc /usr/local/share/ri \
           /usr/local/lib/pkgconfig && \
    find /usr/local/lib -name '*.a' -delete 2>/dev/null || true && \
    find /usr/local -name '*.o' | xargs rm -f 2>/dev/null || true && \
    ldconfig
USER 1000

# =============================================================================
# DEVELOPMENT STAGE - Full development environment
# =============================================================================
FROM build-base AS development

ENV RAILS_ENV="development" \
    BUNDLE_WITHOUT="" \
    BUNDLE_DEPLOYMENT="0" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

COPY --chown=1000:0 --chmod=440 Gemfile Gemfile.lock ./
RUN bundle install

COPY --chown=1000:0 --chmod=440 package.json yarn.lock esbuild.config.js ./
RUN yarn install --frozen-lockfile

COPY --chown=1000:0 . .

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# =============================================================================
# PRODUCTION STAGE - Optimized for deployment (default)
# =============================================================================
FROM base AS production

USER 0

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    RUBY_YJIT_ENABLE="1"

# /opt/node is intentionally NOT copied — production has no Node runtime.
# /rails preserves source-tree modes from the build stage (config files
# stay r--r-----, bin/* stay 0755) — no blanket --chmod that would clobber
# the hardening applied earlier.
COPY --from=build /usr/local /usr/local
COPY --from=build /rails /rails

RUN mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

USER 1000:1000

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

EXPOSE 3000

# Entrypoint handles db:prepare on server start (Rails standard pattern)
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
