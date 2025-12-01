package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"
)

var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "Build Docker images",
	Long: `Build Vulcan Docker images for development or production.

Supports multi-architecture builds using Docker Buildx Bake.

Examples:
  vulcan build                    # Build for current platform
  vulcan build --platform linux/amd64,linux/arm64
  vulcan build --push             # Build and push to registry
  vulcan build --target dev       # Build development image`,
	Run: runBuild,
}

var (
	buildPlatforms string
	buildPush      bool
	buildTarget    string
	buildTag       string
	buildNoCache   bool
)

func init() {
	rootCmd.AddCommand(buildCmd)
	buildCmd.Flags().StringVarP(&buildPlatforms, "platform", "p", "", "Target platforms (e.g., linux/amd64,linux/arm64)")
	buildCmd.Flags().BoolVar(&buildPush, "push", false, "Push images to registry after build")
	buildCmd.Flags().StringVarP(&buildTarget, "target", "t", "production", "Build target (dev, production)")
	buildCmd.Flags().StringVar(&buildTag, "tag", "", "Custom image tag")
	buildCmd.Flags().BoolVar(&buildNoCache, "no-cache", false, "Build without cache")
}

func runBuild(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	printTitle("Building Vulcan Docker Image")
	fmt.Println()

	// Check for docker-bake.hcl, create if missing
	bakePath := projectRoot + "/docker-bake.hcl"
	if _, err := os.Stat(bakePath); os.IsNotExist(err) {
		printInfo("Creating docker-bake.hcl configuration...")
		createBakeFile(bakePath)
		printSuccess("Created docker-bake.hcl")
	}

	// If no platforms specified and pushing, ask user
	if buildPush && buildPlatforms == "" {
		var multiArch bool
		huh.NewConfirm().
			Title("Build for multiple architectures?").
			Description("Recommended for distribution (amd64 + arm64)").
			Value(&multiArch).
			Run()

		if multiArch {
			buildPlatforms = "linux/amd64,linux/arm64"
		}
	}

	// Build command args
	bakeArgs := []string{"buildx", "bake"}

	if buildPlatforms != "" {
		bakeArgs = append(bakeArgs, "--set", fmt.Sprintf("*.platform=%s", buildPlatforms))
	}

	if buildPush {
		bakeArgs = append(bakeArgs, "--push")
	}

	if buildNoCache {
		bakeArgs = append(bakeArgs, "--no-cache")
	}

	if buildTag != "" {
		bakeArgs = append(bakeArgs, "--set", fmt.Sprintf("*.tags=%s", buildTag))
	}

	// Add target
	bakeArgs = append(bakeArgs, buildTarget)

	// Show what we're building
	printInfo(fmt.Sprintf("Target: %s", buildTarget))
	if buildPlatforms != "" {
		printInfo(fmt.Sprintf("Platforms: %s", buildPlatforms))
	}
	if buildPush {
		printInfo("Push: enabled")
	}
	fmt.Println()

	// Check if buildx is available
	checkCmd := exec.Command("docker", "buildx", "version")
	if err := checkCmd.Run(); err != nil {
		printError("Docker Buildx not available. Please install Docker Buildx.")
		os.Exit(1)
	}

	// Ensure builder exists for multi-platform
	if buildPlatforms != "" && strings.Contains(buildPlatforms, ",") {
		ensureMultiPlatformBuilder()
	}

	// Run the build
	printInfo("Building image...")
	fmt.Println()

	dockerCmd := exec.Command("docker", bakeArgs...)
	dockerCmd.Dir = projectRoot
	dockerCmd.Stdout = os.Stdout
	dockerCmd.Stderr = os.Stderr

	if err := dockerCmd.Run(); err != nil {
		printError("Build failed: " + err.Error())
		os.Exit(1)
	}

	fmt.Println()
	printSuccess("Build complete!")

	if !buildPush {
		printInfo("Image available locally. Use --push to push to registry.")
	}
}

func ensureMultiPlatformBuilder() {
	// Check if vulcan-builder exists
	checkCmd := exec.Command("docker", "buildx", "inspect", "vulcan-builder")
	if err := checkCmd.Run(); err != nil {
		printInfo("Creating multi-platform builder...")

		createCmd := exec.Command("docker", "buildx", "create",
			"--name", "vulcan-builder",
			"--driver", "docker-container",
			"--bootstrap",
			"--use")
		createCmd.Run()
	} else {
		// Use existing builder
		useCmd := exec.Command("docker", "buildx", "use", "vulcan-builder")
		useCmd.Run()
	}
}

func createBakeFile(path string) {
	content := `// Vulcan Docker Bake Configuration
// Build with: docker buildx bake [target]
//
// Targets:
//   production  - Production-ready image (default)
//   dev         - Development image with all tools
//   all         - Build all targets

variable "REGISTRY" {
  default = "mitre"
}

variable "IMAGE_NAME" {
  default = "vulcan"
}

variable "VERSION" {
  default = "latest"
}

// Shared settings for all targets
group "default" {
  targets = ["production"]
}

group "all" {
  targets = ["production", "dev"]
}

// Production image - optimized for size and security
target "production" {
  dockerfile = "Dockerfile.production"
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]
  platforms = ["linux/amd64"]
  cache-from = ["type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache"]
  cache-to   = ["type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache,mode=max"]

  args = {
    RUBY_VERSION = "3.3.9"
    NODE_VERSION = "22"
    BUNDLER_VERSION = "2.6.5"
  }
}

// Multi-architecture production build
target "production-multiarch" {
  inherits = ["production"]
  platforms = ["linux/amd64", "linux/arm64"]
}

// Development image - includes dev dependencies
target "dev" {
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:dev"
  ]
  platforms = ["linux/amd64"]
  target = "development"
}

// CI build - for testing
target "ci" {
  inherits = ["production"]
  tags = ["${REGISTRY}/${IMAGE_NAME}:ci-${VERSION}"]
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}
`

	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		printError("Failed to create docker-bake.hcl: " + err.Error())
		os.Exit(1)
	}
}
