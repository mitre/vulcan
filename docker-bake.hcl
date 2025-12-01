// Vulcan Docker Bake Configuration
//
// Build with Docker Buildx Bake:
//   docker buildx bake                    # Build default (production)
//   docker buildx bake production-multiarch  # Multi-arch build
//   docker buildx bake --push             # Build and push
//   docker buildx bake all                # Build all targets
//
// Or use the CLI:
//   vulcan build
//   vulcan build --platform linux/amd64,linux/arm64
//   vulcan build --push
//
// NOTE: RVM sets RUBY_VERSION with "ruby-" prefix (e.g., "ruby-3.4.7").
// We use VULCAN_RUBY_VERSION to avoid this conflict. If you see errors like
// "ruby:ruby-3.4.7-slim not found", either:
//   - Set VULCAN_RUBY_VERSION=3.4.7, or
//   - Run: unset RUBY_VERSION && docker buildx bake

variable "REGISTRY" {
  default = "mitre"
}

variable "IMAGE_NAME" {
  default = "vulcan"
}

variable "VERSION" {
  default = "latest"
}

// Use VULCAN_RUBY_VERSION to avoid conflict with RVM's RUBY_VERSION
variable "VULCAN_RUBY_VERSION" {
  default = "3.4.7"
}

variable "VULCAN_NODE_VERSION" {
  default = "24.11.1"
}

variable "BUNDLER_VERSION" {
  default = "2.6.5"
}

variable "WEB_PORT" {
  default = "3000"
}

variable "PROMETHEUS_PORT" {
  default = "9394"
}

variable "DATABASE_PORT" {
  default = "5432"
}

// ============================================================================
// Groups - Build multiple targets at once
// ============================================================================

group "default" {
  targets = ["production"]
}

group "all" {
  targets = ["production", "dev"]
}

// ============================================================================
// Production Target - Optimized for size and security
// ============================================================================

target "production" {
  dockerfile = "Dockerfile.production"
  context    = "."

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]

  platforms = ["linux/amd64"]

  args = {
    RUBY_VERSION     = "${VULCAN_RUBY_VERSION}"
    NODE_VERSION     = "${VULCAN_NODE_VERSION}"
    BUNDLER_VERSION  = "${BUNDLER_VERSION}"
    WEB_PORT         = "${WEB_PORT}"
    PROMETHEUS_PORT  = "${PROMETHEUS_PORT}"
  }

  labels = {
    "org.opencontainers.image.title"       = "Vulcan"
    "org.opencontainers.image.description" = "STIG authoring and InSpec profile development"
    "org.opencontainers.image.vendor"      = "MITRE"
    "org.opencontainers.image.source"      = "https://github.com/mitre/vulcan"
    "org.opencontainers.image.version"     = "${VERSION}"
  }

  // Build cache configuration
  cache-from = [
    "type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache"
  ]
  cache-to = [
    "type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache,mode=max"
  ]
}

// ============================================================================
// Multi-Architecture Production Build
// ============================================================================

target "production-multiarch" {
  inherits = ["production"]

  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]
}

// ============================================================================
// Development Target - Includes dev tools
// ============================================================================

target "dev" {
  dockerfile = "Dockerfile"
  context    = "."

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:dev"
  ]

  platforms = ["linux/amd64"]

  target = "development"

  args = {
    RUBY_VERSION     = "${VULCAN_RUBY_VERSION}"
    NODE_VERSION     = "${VULCAN_NODE_VERSION}"
    BUNDLER_VERSION  = "${BUNDLER_VERSION}"
    WEB_PORT         = "${WEB_PORT}"
    PROMETHEUS_PORT  = "${PROMETHEUS_PORT}"
  }
}

// ============================================================================
// CI Build - For GitHub Actions
// ============================================================================

target "ci" {
  inherits = ["production"]

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:ci-${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:ci"
  ]

  // Use GitHub Actions cache
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}

// ============================================================================
// CI Multi-Architecture Build
// ============================================================================

target "ci-multiarch" {
  inherits = ["ci"]

  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}

// ============================================================================
// Release Build - For tagged releases
// ============================================================================

target "release" {
  inherits = ["production-multiarch"]

  // Override tags for release
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:latest",
    "ghcr.io/${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "ghcr.io/${REGISTRY}/${IMAGE_NAME}:latest"
  ]
}
