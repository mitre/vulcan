package cmd

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
)

// DockerClient wraps the Docker SDK client for cross-platform container operations.
// Works with Docker Desktop, OrbStack, Podman (via docker socket), and Rancher Desktop.
type DockerClient struct {
	cli *client.Client
}

// ContainerInfo holds information about a running container
type ContainerInfo struct {
	ID      string
	Name    string
	Image   string
	State   string
	Status  string
	Ports   string
	Created time.Time
}

// getDockerSocketPaths returns a list of possible Docker socket paths to try.
// Order matters: environment variable first, then common runtime locations.
func getDockerSocketPaths() []string {
	home := os.Getenv("HOME")
	paths := []string{}

	// If DOCKER_HOST is set, use it first (user override)
	if dockerHost := os.Getenv("DOCKER_HOST"); dockerHost != "" {
		paths = append(paths, dockerHost)
	}

	// Common socket locations (in order of preference)
	commonSockets := []string{
		"/var/run/docker.sock",                    // Standard Docker/Linux
		home + "/.orbstack/run/docker.sock",       // OrbStack
		home + "/.docker/run/docker.sock",         // Docker Desktop (newer)
		home + "/.colima/default/docker.sock",     // Colima
		home + "/.rd/docker.sock",                 // Rancher Desktop
		"/run/podman/podman.sock",                 // Podman (rootful)
		home + "/.local/share/containers/podman/machine/podman.sock", // Podman machine
	}

	for _, sock := range commonSockets {
		// Check if socket exists before adding
		if _, err := os.Stat(strings.TrimPrefix(sock, "unix://")); err == nil {
			if !strings.HasPrefix(sock, "unix://") {
				sock = "unix://" + sock
			}
			paths = append(paths, sock)
		}
	}

	return paths
}

// NewDockerClient creates a new Docker client that auto-detects the runtime.
// Tries multiple socket locations to support Docker Desktop, OrbStack, Colima,
// Rancher Desktop, and Podman on macOS, Linux, and Windows.
func NewDockerClient() (*DockerClient, error) {
	socketPaths := getDockerSocketPaths()

	// If we found sockets to try, attempt each one
	var lastErr error
	for _, sockPath := range socketPaths {
		cli, err := client.NewClientWithOpts(
			client.WithHost(sockPath),
			client.WithAPIVersionNegotiation(),
		)
		if err != nil {
			lastErr = err
			continue
		}

		// Test the connection
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_, err = cli.Ping(ctx)
		cancel()

		if err == nil {
			return &DockerClient{cli: cli}, nil
		}

		cli.Close()
		lastErr = err
	}

	// Fallback: try default SDK behavior (reads DOCKER_HOST, uses defaults)
	cli, err := client.NewClientWithOpts(
		client.FromEnv,
		client.WithAPIVersionNegotiation(),
	)
	if err != nil {
		if lastErr != nil {
			return nil, fmt.Errorf("failed to create Docker client: %w (also tried: %v)", err, lastErr)
		}
		return nil, fmt.Errorf("failed to create Docker client: %w", err)
	}

	return &DockerClient{cli: cli}, nil
}

// Close closes the Docker client connection
func (d *DockerClient) Close() error {
	return d.cli.Close()
}

// Ping checks if the Docker daemon is accessible
func (d *DockerClient) Ping(ctx context.Context) error {
	_, err := d.cli.Ping(ctx)
	return err
}

// GetRuntimeInfo returns information about the Docker runtime
func (d *DockerClient) GetRuntimeInfo(ctx context.Context) (string, string, error) {
	info, err := d.cli.Info(ctx)
	if err != nil {
		return "", "", err
	}

	// Detect runtime type
	runtimeType := "Docker"
	if strings.Contains(info.OperatingSystem, "OrbStack") {
		runtimeType = "OrbStack"
	} else if strings.Contains(info.Name, "podman") || strings.Contains(strings.ToLower(info.OperatingSystem), "podman") {
		runtimeType = "Podman"
	} else if strings.Contains(info.Name, "rancher") {
		runtimeType = "Rancher Desktop"
	}

	version := info.ServerVersion
	return runtimeType, version, nil
}

// ListContainers returns all running containers
func (d *DockerClient) ListContainers(ctx context.Context, all bool) ([]ContainerInfo, error) {
	containers, err := d.cli.ContainerList(ctx, container.ListOptions{All: all})
	if err != nil {
		return nil, err
	}

	var result []ContainerInfo
	for _, c := range containers {
		name := ""
		if len(c.Names) > 0 {
			name = strings.TrimPrefix(c.Names[0], "/")
		}

		ports := formatPorts(c.Ports)

		result = append(result, ContainerInfo{
			ID:      c.ID[:12],
			Name:    name,
			Image:   c.Image,
			State:   c.State,
			Status:  c.Status,
			Ports:   ports,
			Created: time.Unix(c.Created, 0),
		})
	}

	return result, nil
}

// ListContainersByLabel returns containers matching a label filter
func (d *DockerClient) ListContainersByLabel(ctx context.Context, label string) ([]ContainerInfo, error) {
	f := filters.NewArgs()
	f.Add("label", label)

	containers, err := d.cli.ContainerList(ctx, container.ListOptions{
		All:     true,
		Filters: f,
	})
	if err != nil {
		return nil, err
	}

	var result []ContainerInfo
	for _, c := range containers {
		name := ""
		if len(c.Names) > 0 {
			name = strings.TrimPrefix(c.Names[0], "/")
		}

		result = append(result, ContainerInfo{
			ID:     c.ID[:12],
			Name:   name,
			Image:  c.Image,
			State:  c.State,
			Status: c.Status,
		})
	}

	return result, nil
}

// GetContainerLogs streams logs from a container
func (d *DockerClient) GetContainerLogs(ctx context.Context, containerID string, follow bool, tail string) (io.ReadCloser, error) {
	options := container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Follow:     follow,
		Tail:       tail,
	}

	return d.cli.ContainerLogs(ctx, containerID, options)
}

// IsContainerRunning checks if a container is running
func (d *DockerClient) IsContainerRunning(ctx context.Context, nameOrID string) (bool, error) {
	containers, err := d.cli.ContainerList(ctx, container.ListOptions{
		All: true,
		Filters: filters.NewArgs(
			filters.Arg("name", nameOrID),
		),
	})
	if err != nil {
		return false, err
	}

	for _, c := range containers {
		if c.State == "running" {
			return true, nil
		}
	}

	return false, nil
}

// ExecInContainer runs a command in a container and returns the output
func (d *DockerClient) ExecInContainer(ctx context.Context, containerID string, cmd []string) (string, error) {
	execConfig := container.ExecOptions{
		Cmd:          cmd,
		AttachStdout: true,
		AttachStderr: true,
	}

	execID, err := d.cli.ContainerExecCreate(ctx, containerID, execConfig)
	if err != nil {
		return "", err
	}

	resp, err := d.cli.ContainerExecAttach(ctx, execID.ID, container.ExecAttachOptions{})
	if err != nil {
		return "", err
	}
	defer resp.Close()

	output, err := io.ReadAll(resp.Reader)
	if err != nil {
		return "", err
	}

	return string(output), nil
}

// formatPorts formats port bindings for display
func formatPorts(ports []types.Port) string {
	var parts []string
	for _, p := range ports {
		if p.PublicPort > 0 {
			parts = append(parts, fmt.Sprintf("%s:%d->%d/%s",
				p.IP, p.PublicPort, p.PrivatePort, p.Type))
		}
	}
	return strings.Join(parts, ", ")
}

// DetectRuntime returns the detected container runtime without needing a full client
func DetectRuntime() string {
	cli, err := NewDockerClient()
	if err != nil {
		return "none"
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	runtime, _, err := cli.GetRuntimeInfo(ctx)
	if err != nil {
		return "none"
	}

	return runtime
}

// IsDockerAvailable checks if Docker/Podman is available
func IsDockerAvailable() bool {
	cli, err := NewDockerClient()
	if err != nil {
		return false
	}
	defer cli.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	return cli.Ping(ctx) == nil
}

// PrintDockerStatus prints a formatted status of all containers
func PrintDockerStatus(ctx context.Context, w io.Writer) error {
	cli, err := NewDockerClient()
	if err != nil {
		fmt.Fprintf(w, "  %s Docker not available: %s\n", errorStyle.Render("●"), err)
		return err
	}
	defer cli.Close()

	// Get runtime info
	runtime, version, err := cli.GetRuntimeInfo(ctx)
	if err != nil {
		fmt.Fprintf(w, "  %s Cannot connect to Docker: %s\n", errorStyle.Render("●"), err)
		return err
	}

	fmt.Fprintf(w, "  %s %s v%s\n", successStyle.Render("●"), runtime, version)
	fmt.Fprintln(w)

	// List containers
	containers, err := cli.ListContainers(ctx, false)
	if err != nil {
		fmt.Fprintf(w, "  %s Cannot list containers: %s\n", errorStyle.Render("●"), err)
		return err
	}

	if len(containers) == 0 {
		fmt.Fprintf(w, "  %s No containers running\n", infoStyle.Render("→"))
		return nil
	}

	// Categorize containers
	var relevant, other []ContainerInfo
	for _, c := range containers {
		isRelevant := strings.Contains(strings.ToLower(c.Name), "vulcan") ||
			strings.Contains(strings.ToLower(c.Name), "postgres") ||
			strings.Contains(strings.ToLower(c.Image), "postgres") ||
			strings.Contains(strings.ToLower(c.Name), "redis") ||
			strings.Contains(strings.ToLower(c.Image), "redis")

		if isRelevant {
			relevant = append(relevant, c)
		} else {
			other = append(other, c)
		}
	}

	if len(relevant) > 0 {
		fmt.Fprintln(w, "  Relevant:")
		for _, c := range relevant {
			status := successStyle.Render("●")
			if c.State != "running" {
				status = errorStyle.Render("●")
			}
			line := fmt.Sprintf("%s (%s)", c.Name, c.Image)
			if c.Ports != "" {
				line += fmt.Sprintf(" [%s]", c.Ports)
			}
			fmt.Fprintf(w, "    %s %s\n", status, line)
		}
	}

	if len(other) > 0 {
		fmt.Fprintln(w, "  Other:")
		for _, c := range other {
			status := successStyle.Render("●")
			if c.State != "running" {
				status = errorStyle.Render("●")
			}
			fmt.Fprintf(w, "    %s %s (%s)\n", status, c.Name, c.Image)
		}
	}

	return nil
}
