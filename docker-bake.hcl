// Vulcan v2.2.x Docker Bake Configuration
//
// Build with Docker Buildx Bake:
//   docker buildx bake                    # Build default (production)
//   docker buildx bake production-multiarch  # Multi-arch build
//   docker buildx bake --push             # Build and push
//   docker buildx bake all                # Build all targets
//
// Or use the CLI:
//   bin/vulcan build
//   bin/vulcan build --platform linux/amd64,linux/arm64
//   bin/vulcan build --push
//
// NOTE: RVM sets RUBY_VERSION with a "ruby-" prefix in some environments.
// We use VULCAN_RUBY_VERSION to avoid this conflict. If a prefixed value leaks into
// the build, you may see an invalid Ruby source download URL or a failure to fetch
// the Ruby tarball. Either:
//   - Set VULCAN_RUBY_VERSION=3.3.9, or
//   - Run: unset RUBY_VERSION && docker buildx bake
// The Dockerfile uses a fixed UBI minimal base image and builds Ruby from source based on the var.

variable "REGISTRY" {
  default = "mitre"
}

variable "IMAGE_NAME" {
  default = "vulcan"
}

variable "VERSION" {
  default = "latest"
}

variable "VULCAN_BUNDLER_VERSION" {
  default = "2.7.2"
}

variable "VULCAN_RUBY_VERSION" {
  default = "3.4.9"
}

variable "VULCAN_NODE_VERSION" {
  default = "24.14.0"
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
  dockerfile = "Dockerfile"
  context    = "."
  target     = "production"

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]

  platforms = ["linux/amd64"]

  args = {
    BUNDLER_VERSION = "${VULCAN_BUNDLER_VERSION}"
    RUBY_VERSION = "${VULCAN_RUBY_VERSION}"
    NODE_VERSION = "${VULCAN_NODE_VERSION}"
  }

  labels = {
    "org.opencontainers.image.title"       = "Vulcan"
    "org.opencontainers.image.description" = "STIG authoring and InSpec profile development"
    "org.opencontainers.image.vendor"      = "MITRE"
    "org.opencontainers.image.source"      = "https://github.com/mitre/vulcan"
    "org.opencontainers.image.version"     = "${VERSION}"
  }

  // Build cache configuration (only for CI/registry push)
  // Uncomment for CI builds with registry access
  // cache-from = ["type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache"]
  // cache-to = ["type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache,mode=max"]
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
// Development Target - Full dev environment with all dependencies
// ============================================================================

target "dev" {
  dockerfile = "Dockerfile"
  context    = "."
  target     = "development"

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:dev"
  ]

  platforms = ["linux/amd64"]

  args = {
    BUNDLER_VERSION = "${VULCAN_BUNDLER_VERSION}"
    RUBY_VERSION = "${VULCAN_RUBY_VERSION}"
    NODE_VERSION = "${VULCAN_NODE_VERSION}"
  }

  labels = {
    "org.opencontainers.image.title"       = "Vulcan Development"
    "org.opencontainers.image.description" = "Vulcan development environment with all dependencies"
    "org.opencontainers.image.vendor"      = "MITRE"
    "org.opencontainers.image.source"      = "https://github.com/mitre/vulcan"
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

  // GitHub Actions cache
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
