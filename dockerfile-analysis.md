# Dockerfile Comparison Analysis

**Problem:** Generated dockerfile-rails Dockerfile fails to build fast_excel gem
**Fact:** Custom Dockerfile.production builds successfully

## Key Differences

### 1. Build Packages

**Custom Dockerfile.production (WORKS):**
```dockerfile
build-essential
git
gnupg
libpq-dev
libyaml-dev
pkg-config
zlib1g-dev
```

**Generated Dockerfile (FAILS):**
```dockerfile
build-essential
gnupg          # Added manually
libffi-dev
libpq-dev
libxlsxwriter-dev  # Added manually - doesn't exist in repos!
libyaml-dev
node-gyp
pkg-config
python-is-python3
```

**Missing from generated:**
- `zlib1g-dev` - Compression library (likely needed by fast_excel)
- `git` - Was added but might not be in right order

**Problem:** `libxlsxwriter-dev` doesn't exist in Debian repos!

### 2. Node.js Installation

**Custom (WORKS):**
```dockerfile
# Using official binaries directly
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}.13.0/node-v${NODE_VERSION}.13.0-linux-${ARCH}.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz && \
    npm install -g yarn
```

**Generated (FAILS):**
```dockerfile
# Using node-build from GitHub
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master
```

**Problem:** node-build download was failing earlier (network issue)

### 3. Bundle Install Order

**Custom:**
- Installs CA certs FIRST
- Sets NODE_EXTRA_CA_CERTS
- Then does bundle install

**Generated:**
- Installs CA certs in base stage
- But build stage might not inherit all cert settings properly

## Root Cause Analysis

**fast_excel gem requirements:**
1. FFI binding to libxlsxwriter C library
2. libxlsxwriter is NOT in Debian package repos
3. fast_excel gem bundles the C library source code
4. Compilation requires: zlib, possibly other compression libs

**Why custom Dockerfile works:**
- Has `zlib1g-dev` package
- This allows fast_excel to compile its bundled libxlsxwriter

**Why generated fails:**
- Missing `zlib1g-dev`
- Tried to add non-existent `libxlsxwriter-dev` package

## Solution

Add `zlib1g-dev` to build packages:
```bash
rails generate dockerfile --add-build zlib1g-dev --force
```

## Other Considerations

The generated Dockerfile uses a different Node.js installation method that may be less reliable than direct binary download. Consider customizing this if node-build continues to have issues.

## Recommendation

1. Add zlib1g-dev
2. Remove libxlsxwriter-dev (doesn't exist)
3. Test build again
4. If still fails, may need to add cmake or other build tools
