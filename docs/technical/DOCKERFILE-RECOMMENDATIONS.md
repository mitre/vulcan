# Dockerfile Optimization Recommendations

## Current Issues with Existing Dockerfile

1. **No multi-stage build** - Results in larger image with build tools
2. **Multiple RUN commands** - Creates unnecessary layers
3. **Missing jemalloc** - Not using Ruby's recommended memory allocator
4. **Using full Ruby image** - Should use slim variant
5. **No health check** - No way to verify container health
6. **Security concerns** - Not removing source/test files from production image

## Three Dockerfile Options

### 1. Current Dockerfile (Working but not optimized)
- **Size**: ~1.5GB
- **Pros**: Works, handles SSL certs
- **Cons**: Large, includes dev dependencies, multiple layers

### 2. Dockerfile.optimized (Better practices)
- **Size**: ~1.2GB
- **Pros**: Combined RUN commands, removed dev dependencies
- **Cons**: Still single-stage, no jemalloc

### 3. Dockerfile.production (Rails 7.2+ best practices)
- **Size**: ~600MB
- **Pros**:
  - Multi-stage build
  - Slim base image
  - jemalloc for 20-40% memory reduction
  - Bootsnap precompilation for faster boot
  - Health check included
  - Follows official Rails template
- **Cons**: More complex, requires understanding of multi-stage builds

## Recommendation

For production, use **Dockerfile.production** with these benefits:

### Memory Optimization
```dockerfile
# jemalloc reduces memory by 20-40%
ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so"
ENV MALLOC_ARENA_MAX="2"
```

### Size Reduction
- Multi-stage build removes build tools
- Slim base image (200MB vs 900MB)
- Final image ~600MB vs 1.5GB

### Security Improvements
- Non-root user (UID 1000)
- Minimal attack surface
- No source code or tests in production

### Performance Gains
- Bootsnap precompilation
- Asset precompilation in build stage
- jemalloc for better memory management

## Migration Path

1. **Test current Dockerfile** (done ✅)
2. **Try Dockerfile.optimized** for quick wins
3. **Move to Dockerfile.production** for full optimization

## Key Differences from Rails defaults

Our app needs:
- Custom SSL certificates
- esbuild instead of default asset pipeline
- No database migration on startup (managed separately)

## Docker Build Commands

```bash
# Development/testing
docker build -f Dockerfile -t vulcan:current .

# Optimized version
docker build -f Dockerfile.optimized -t vulcan:optimized .

# Production (recommended)
docker build -f Dockerfile.production -t vulcan:production .
```

## Size Comparison

```bash
# Check image sizes
docker images | grep vulcan

# Expected results:
# vulcan:production    ~600MB  (60% smaller)
# vulcan:optimized     ~1.2GB  (20% smaller)
# vulcan:current       ~1.5GB  (baseline)
```

## Next Steps

1. Test Dockerfile.production with SSL certificates
2. Benchmark memory usage with jemalloc
3. Update CI/CD to use production Dockerfile
4. Document the multi-stage build process