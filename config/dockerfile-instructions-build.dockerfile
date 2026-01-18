# Build stage instructions: Configure npm/yarn for CA certificates

# Configure npm and yarn to use system CA certificates (after Node.js is installed)
RUN npm config set cafile /etc/ssl/certs/ca-certificates.crt && \
    yarn config set cafile /etc/ssl/certs/ca-certificates.crt
