package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"
)

var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "Build Docker images",
	Long: `Build Vulcan Docker images for development or production.

Supports multi-architecture builds using Docker Buildx Bake.
Automatically loads configuration from vulcan.yaml, .env, and version files.

Configuration is loaded from multiple sources (lowest to highest priority):
  1. Built-in defaults
  2. vulcan.yaml (or .json, .toml) in project root
  3. .env file
  4. Environment variables (VULCAN_* prefix)
  5. Command-line flags

Examples:
  vulcan build                    # Build production image
  vulcan build --target dev       # Build development image
  vulcan build --info             # Show build configuration
  vulcan build --push             # Build and push to registry
  vulcan build -p linux/amd64,linux/arm64 --push  # Multi-arch build
  vulcan build --ruby-version 3.4.7 --node-version 24
  vulcan build --registry ghcr.io/mitre --version v2.3.0`,
	Run: runBuild,
}

var buildInfoCmd = &cobra.Command{
	Use:   "info",
	Short: "Show build configuration",
	Long: `Display the build configuration that will be used, without building.

Shows all configuration values and their sources (defaults, config file,
environment variables, or command-line flags).`,
	Run:   runBuildInfo,
}

var (
	buildPlatforms      string
	buildPush           bool
	buildTarget         string
	buildTag            string
	buildNoCache        bool
	buildShowInfo       bool
	buildRubyVersion    string
	buildNodeVersion    string
	buildRegistry       string
	buildImageName      string
	buildVersion        string
	buildWebPort        string
	buildPrometheusPort string
)

func init() {
	rootCmd.AddCommand(buildCmd)
	buildCmd.AddCommand(buildInfoCmd)

	// Build control flags
	buildCmd.Flags().StringVarP(&buildPlatforms, "platform", "p", "",
		"Target platforms (e.g., linux/amd64,linux/arm64)")
	buildCmd.Flags().BoolVar(&buildPush, "push", false,
		"Push images to registry after build")
	buildCmd.Flags().StringVarP(&buildTarget, "target", "t", "production",
		"Build target: production, dev, ci, production-multiarch")
	buildCmd.Flags().StringVar(&buildTag, "tag", "",
		"Custom image tag (overrides version)")
	buildCmd.Flags().BoolVar(&buildNoCache, "no-cache", false,
		"Build without cache")
	buildCmd.Flags().BoolVar(&buildShowInfo, "info", false,
		"Show build configuration without building")

	// Version override flags
	buildCmd.Flags().StringVar(&buildRubyVersion, "ruby-version", "",
		"Ruby version (default: from .ruby-version or config)")
	buildCmd.Flags().StringVar(&buildNodeVersion, "node-version", "",
		"Node.js version (default: from config)")

	// Image configuration flags
	buildCmd.Flags().StringVar(&buildRegistry, "registry", "",
		"Docker registry (default: mitre)")
	buildCmd.Flags().StringVar(&buildImageName, "image", "",
		"Image name (default: vulcan)")
	buildCmd.Flags().StringVar(&buildVersion, "version", "",
		"Image version tag (default: latest)")

	// Port configuration flags
	buildCmd.Flags().StringVar(&buildWebPort, "port", "",
		"Web server port (default: 3000)")
	buildCmd.Flags().StringVar(&buildPrometheusPort, "prometheus-port", "",
		"Prometheus metrics port (default: 9394)")
}

// getBuildSettings returns build configuration from Viper with CLI overrides
func getBuildSettings() BuildSettings {
	config := GetConfig()
	settings := config.Build

	// Override with command-line flags (highest priority)
	if buildRubyVersion != "" {
		settings.RubyVersion = buildRubyVersion
	}
	if buildNodeVersion != "" {
		settings.NodeVersion = buildNodeVersion
	}
	if buildRegistry != "" {
		settings.Registry = buildRegistry
	}
	if buildImageName != "" {
		settings.Image = buildImageName
	}
	if buildVersion != "" {
		settings.Version = buildVersion
	}

	return settings
}

// getPortSettings returns port configuration from Viper with CLI overrides
func getPortSettings() PortSettings {
	config := GetConfig()
	ports := config.Ports

	// Override with command-line flags
	if buildWebPort != "" {
		if port, err := strconv.Atoi(buildWebPort); err == nil {
			ports.Web = port
		}
	}
	if buildPrometheusPort != "" {
		if port, err := strconv.Atoi(buildPrometheusPort); err == nil {
			ports.Prometheus = port
		}
	}

	return ports
}

func runBuildInfo(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	build := getBuildSettings()
	ports := getPortSettings()

	printTitle("Build Configuration")
	fmt.Println()

	// Check config file used
	if cfgFile := GetViper().ConfigFileUsed(); cfgFile != "" {
		printInfo(fmt.Sprintf("Config file: %s", cfgFile))
		fmt.Println()
	}

	printInfo("Version Information:")
	fmt.Printf("  Ruby Version:    %s\n", build.RubyVersion)
	fmt.Printf("  Node Version:    %s\n", build.NodeVersion)
	fmt.Printf("  Bundler Version: %s\n", build.BundlerVersion)
	fmt.Println()

	printInfo("Image Configuration:")
	fmt.Printf("  Registry:        %s\n", build.Registry)
	fmt.Printf("  Image Name:      %s\n", build.Image)
	fmt.Printf("  Version Tag:     %s\n", build.Version)
	fmt.Printf("  Full Image:      %s/%s:%s\n", build.Registry, build.Image, build.Version)
	fmt.Println()

	printInfo("Port Configuration:")
	fmt.Printf("  Web Port:        %d\n", ports.Web)
	fmt.Printf("  Prometheus Port: %d\n", ports.Prometheus)
	fmt.Printf("  Database Port:   %d\n", ports.Database)
	fmt.Println()

	// Show docker bake print output
	printInfo("Docker Bake Configuration:")
	bakeCmd := exec.Command("docker", "buildx", "bake", "--print", buildTarget)
	bakeCmd.Dir = projectRoot
	bakeCmd.Env = append(os.Environ(),
		fmt.Sprintf("RUBY_VERSION=%s", build.RubyVersion),
		fmt.Sprintf("NODE_VERSION=%s", build.NodeVersion),
		fmt.Sprintf("REGISTRY=%s", build.Registry),
		fmt.Sprintf("IMAGE_NAME=%s", build.Image),
		fmt.Sprintf("VERSION=%s", build.Version),
		fmt.Sprintf("WEB_PORT=%d", ports.Web),
		fmt.Sprintf("PROMETHEUS_PORT=%d", ports.Prometheus),
	)
	bakeCmd.Stdout = os.Stdout
	bakeCmd.Stderr = os.Stderr
	bakeCmd.Run()
}

func runBuild(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	// Load build configuration from Viper
	build := getBuildSettings()
	ports := getPortSettings()

	// If --info flag, just show info and exit
	if buildShowInfo {
		runBuildInfo(cmd, args)
		return
	}

	printTitle("Building Vulcan Docker Image")
	fmt.Println()

	// Check for docker-bake.hcl
	bakePath := filepath.Join(projectRoot, "docker-bake.hcl")
	if _, err := os.Stat(bakePath); os.IsNotExist(err) {
		printError("docker-bake.hcl not found. Please ensure it exists in the project root.")
		os.Exit(1)
	}

	// Check Dockerfile exists for target
	dockerfilePath := filepath.Join(projectRoot, "Dockerfile.production")
	if buildTarget == "dev" {
		dockerfilePath = filepath.Join(projectRoot, "Dockerfile")
	}
	if _, err := os.Stat(dockerfilePath); os.IsNotExist(err) {
		printError(fmt.Sprintf("Dockerfile not found: %s", dockerfilePath))
		os.Exit(1)
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

	// Build environment variables for docker buildx bake
	buildEnv := []string{
		fmt.Sprintf("RUBY_VERSION=%s", build.RubyVersion),
		fmt.Sprintf("NODE_VERSION=%s", build.NodeVersion),
		fmt.Sprintf("BUNDLER_VERSION=%s", build.BundlerVersion),
		fmt.Sprintf("REGISTRY=%s", build.Registry),
		fmt.Sprintf("IMAGE_NAME=%s", build.Image),
		fmt.Sprintf("VERSION=%s", build.Version),
		fmt.Sprintf("WEB_PORT=%d", ports.Web),
		fmt.Sprintf("PROMETHEUS_PORT=%d", ports.Prometheus),
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
	printInfo("Build Configuration:")
	fmt.Printf("  Target:     %s\n", buildTarget)
	fmt.Printf("  Image:      %s/%s:%s\n", build.Registry, build.Image, build.Version)
	fmt.Printf("  Ruby:       %s\n", build.RubyVersion)
	fmt.Printf("  Node:       %s\n", build.NodeVersion)
	if buildPlatforms != "" {
		fmt.Printf("  Platforms:  %s\n", buildPlatforms)
	}
	if buildPush {
		fmt.Printf("  Push:       enabled\n")
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
	dockerCmd.Env = append(os.Environ(), buildEnv...)
	dockerCmd.Stdout = os.Stdout
	dockerCmd.Stderr = os.Stderr

	if err := dockerCmd.Run(); err != nil {
		printError("Build failed: " + err.Error())
		os.Exit(1)
	}

	fmt.Println()
	printSuccess("Build complete!")
	fmt.Printf("  Image: %s/%s:%s\n", build.Registry, build.Image, build.Version)

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
    RUBY_VERSION = "3.4.7"
    NODE_VERSION = "24"
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
