package cmd

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

func TestIsDockerAvailable(t *testing.T) {
	// This test checks if Docker is available on the system
	// It will pass if Docker is running, skip if not
	available := IsDockerAvailable()
	if !available {
		t.Skip("Docker not available, skipping Docker-dependent tests")
	}
}

func TestNewDockerClient(t *testing.T) {
	cli, err := NewDockerClient()
	if err != nil {
		t.Skip("Docker not available: " + err.Error())
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = cli.Ping(ctx)
	if err != nil {
		t.Errorf("Failed to ping Docker: %v", err)
	}
}

func TestGetRuntimeInfo(t *testing.T) {
	cli, err := NewDockerClient()
	if err != nil {
		t.Skip("Docker not available")
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	runtime, version, err := cli.GetRuntimeInfo(ctx)
	if err != nil {
		t.Errorf("Failed to get runtime info: %v", err)
	}

	if runtime == "" {
		t.Error("Runtime should not be empty")
	}

	if version == "" {
		t.Error("Version should not be empty")
	}

	t.Logf("Detected runtime: %s v%s", runtime, version)
}

func TestListContainers(t *testing.T) {
	cli, err := NewDockerClient()
	if err != nil {
		t.Skip("Docker not available")
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	containers, err := cli.ListContainers(ctx, false)
	if err != nil {
		t.Errorf("Failed to list containers: %v", err)
	}

	// Just verify it returns without error
	// Number of containers depends on system state
	t.Logf("Found %d running containers", len(containers))
}

func TestDetectRuntime(t *testing.T) {
	runtime := DetectRuntime()

	// Should return one of: Docker, OrbStack, Podman, Rancher Desktop, or "none"
	validRuntimes := map[string]bool{
		"Docker":          true,
		"OrbStack":        true,
		"Podman":          true,
		"Rancher Desktop": true,
		"none":            true,
	}

	if !validRuntimes[runtime] {
		t.Errorf("Unexpected runtime: %s", runtime)
	}

	t.Logf("Detected runtime: %s", runtime)
}

func TestGetDockerSocketPaths(t *testing.T) {
	paths := getDockerSocketPaths()

	t.Logf("Found %d potential socket paths", len(paths))
	for i, p := range paths {
		t.Logf("  [%d] %s", i, p)
	}

	// Should find at least one socket on a system with Docker/OrbStack/etc
	if len(paths) == 0 {
		t.Log("No Docker sockets found - this is expected if no container runtime is installed")
	}

	// All paths should be valid unix socket URIs
	for _, p := range paths {
		if !strings.HasPrefix(p, "unix://") {
			t.Errorf("Socket path should have unix:// prefix: %s", p)
		}
	}
}

func TestGetDockerSocketPathsWithEnvOverride(t *testing.T) {
	// Save original DOCKER_HOST
	originalHost := os.Getenv("DOCKER_HOST")
	defer os.Setenv("DOCKER_HOST", originalHost)

	// Set custom DOCKER_HOST
	testHost := "unix:///tmp/test-docker.sock"
	os.Setenv("DOCKER_HOST", testHost)

	paths := getDockerSocketPaths()

	if len(paths) == 0 {
		t.Fatal("Expected at least one path when DOCKER_HOST is set")
	}

	// First path should be the env override
	if paths[0] != testHost {
		t.Errorf("First path should be DOCKER_HOST value, got: %s", paths[0])
	}
}

func TestNewDockerClientAutoDetect(t *testing.T) {
	// This tests the auto-detection logic
	cli, err := NewDockerClient()
	if err != nil {
		// Not an error if no Docker runtime available
		t.Logf("Docker client creation failed (expected if no runtime): %v", err)
		return
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	runtime, version, err := cli.GetRuntimeInfo(ctx)
	if err != nil {
		t.Errorf("Failed to get runtime info after auto-detect: %v", err)
		return
	}

	t.Logf("Auto-detected and connected to: %s v%s", runtime, version)
}
