package cmd

import (
	"context"
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
