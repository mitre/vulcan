# Custom instructions for base stage: Install corporate CA certificates and proxy support

# Proxy support for corporate environments (optional build args)
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

# Install custom SSL certificates from certs/ directory
COPY certs/ /usr/local/share/ca-certificates/custom/
RUN cd /usr/local/share/ca-certificates/custom && \
    for cert in ./*.pem ./*.cer; do \
      [ -f "$cert" ] && mv "$cert" "${cert%.*}.crt" || true; \
    done && \
    if ls ./*.crt 2>/dev/null | grep -q .; then \
      apt-get update -qq && \
      apt-get install --no-install-recommends -y ca-certificates && \
      update-ca-certificates && \
      rm -rf /var/lib/apt/lists /var/cache/apt/archives; \
    fi && \
    cd /rails

# Configure all tools to use system CA certificates
# Supports multiple standards so it works regardless of user's environment
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Set proxy env vars if provided (for yarn/npm behind corporate proxy)
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY}
