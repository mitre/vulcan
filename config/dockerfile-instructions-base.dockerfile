# Custom instructions for base stage: Install corporate CA certificates

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

# Set Node and Ruby to use custom certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
