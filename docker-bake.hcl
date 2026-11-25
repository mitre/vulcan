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
//   - Set VULCAN_RUBY_VERSION=3.4.13, or
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

variable "TAG_SUFFIXES" {
  default = "latest"
}

variable "VULCAN_RUBY_VERSION" {
  default = "3.4.13"
}

variable "VULCAN_NODE_VERSION" {
  default = "24.22.2"
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
    RUBY_VERSION = "${VULCAN_RUBY_VERSION}"
    NODE_VERSION = "${VULCAN_NODE_VERSION}"
  }

  labels = {
    "org.opencontainers.image.title"       = "Vulcan"
    "org.opencontainers.image.description" = "STIG authoring and InSpec profile development"
    "org.opencontainers.image.vendor"      = "MITRE"
    "org.opencontainers.image.source"      = "https://github.com/mitre/vulcan"
    "org.opencontainers.image.version"     = "${VERSION}"
    "org.opencontainers.image.base.name"   = "registry.access.redhat.com/ubi9/ubi-minimal:9.8"
  }

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
}

// ============================================================================
// Registry Push - For the release + mainline CI workflows
// ============================================================================
// The tag list is supplied by the workflow as a comma-separated TAG_SUFFIXES:
//   release:  TAG_SUFFIXES="<x.y.z>,release-latest"
//   mainline: TAG_SUFFIXES="<git sha>,latest"
// The first suffix is the immutable version and is surfaced as the image label.
//
// NOTE: no cache-from / cache-to here, on purpose.
//
// The emulated driver is the default everywhere, and those builds run 62-64
// minutes, so a `type=gha` cache genuinely would help. It is still the wrong
// trade here:
//
//   `gh api repos/mitre/vulcan/actions/cache/usage` reports 9.57 GB live
//   across 84 caches against GitHub's 10 GB per-repository ceiling. A
//   mode=max export of a two-architecture UBI9 image that compiles Ruby and
//   jemalloc from source runs to several GB, so writing image layers there
//   would evict ci.yml's gem and Yarn caches by LRU on *every* push to master
//   - buying mainline latency we do not need at the price of slower CI on
//   every pull request.
//
// On the opt-in Build Cloud driver the question does not arise: that builder
// keeps its own persistent per-architecture cache and a cold build of this
// target measured 2m35s, leaving no build time for a cache to recover.
//
// `cache-from` without a writer is a no-op, so it is not configured either.
// The `ci` target below keeps `type=gha` because it is single-architecture and
// small. Revisit this if ci.yml's cache footprint shrinks enough to leave
// room, or if the build moves to native per-architecture runners (which would
// cut the build without needing a cache at all).

target "registry" {
  inherits = ["production-multiarch"]

  tags = [for s in split(",", TAG_SUFFIXES) : "${REGISTRY}/${IMAGE_NAME}:${trimspace(s)}"]

  labels = {
    "org.opencontainers.image.version" = trimspace(split(",", TAG_SUFFIXES)[0])
  }
}

// ============================================================================
// Development Target - Full dev environment with all dependencies
// ============================================================================

target "dev" {
  inherits = ["production"]
  target   = "development"

  tags = [
    "${REGISTRY}/${IMAGE_NAME}:dev"
  ]

  labels = {
    "org.opencontainers.image.title"       = "Vulcan Development"
    "org.opencontainers.image.description" = "Vulcan development environment with all dependencies"
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
