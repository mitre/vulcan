package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show Vulcan service status",
	Long:  `Display the status of all Vulcan services and health checks.`,
	Run:   runStatus,
}

func init() {
	rootCmd.AddCommand(statusCmd)
}

func runStatus(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	printTitle("Vulcan Status")
	fmt.Println()

	// Check container runtime via Docker SDK (cross-platform)
	checkContainerRuntimeSDK()

	// Check PostgreSQL via Rails (the authoritative source)
	checkPostgresViaRails()

	// Check Docker services via SDK (cross-platform)
	checkDockerServicesSDK(projectRoot)

	// Check health endpoints
	checkHealthEndpoints()
}

// checkContainerRuntimeSDK uses the Docker SDK for cross-platform runtime detection
func checkContainerRuntimeSDK() {
	fmt.Println(subtitleStyle.Render("Container Runtime"))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cli, err := NewDockerClient()
	if err != nil {
		fmt.Printf("  %s No container runtime available\n", errorStyle.Render("●"))
		fmt.Printf("    %s Install Docker Desktop, OrbStack, or Podman\n", infoStyle.Render("→"))
		fmt.Println()
		return
	}
	defer cli.Close()

	runtime, version, err := cli.GetRuntimeInfo(ctx)
	if err != nil {
		fmt.Printf("  %s Cannot connect to container runtime: %s\n", errorStyle.Render("●"), err)
		fmt.Println()
		return
	}

	fmt.Printf("  %s %s v%s\n", successStyle.Render("●"), runtime, version)
	fmt.Println()
}

// checkDockerServicesSDK uses Docker SDK for cross-platform container listing
func checkDockerServicesSDK(projectRoot string) {
	fmt.Println(subtitleStyle.Render("Docker Containers"))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cli, err := NewDockerClient()
	if err != nil {
		printInfo("Docker not accessible")
		fmt.Println()
		return
	}
	defer cli.Close()

	containers, err := cli.ListContainers(ctx, false)
	if err != nil {
		printInfo("Cannot list containers")
		fmt.Println()
		return
	}

	if len(containers) == 0 {
		printInfo("No containers running")
		fmt.Println()
		return
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
		fmt.Println("  Relevant:")
		for _, c := range relevant {
			status := successStyle.Render("●")
			if c.State != "running" {
				status = errorStyle.Render("●")
			}
			line := fmt.Sprintf("%s (%s)", c.Name, c.Image)
			if c.Ports != "" {
				line += fmt.Sprintf(" [%s]", c.Ports)
			}
			fmt.Printf("    %s %s\n", status, line)
		}
	}

	if len(other) > 0 {
		fmt.Println("  Other:")
		// Limit to first 10 to avoid spam
		shown := 0
		for _, c := range other {
			if shown >= 10 {
				fmt.Printf("    %s ... and %d more\n", infoStyle.Render("→"), len(other)-10)
				break
			}
			status := successStyle.Render("●")
			if c.State != "running" {
				status = errorStyle.Render("●")
			}
			fmt.Printf("    %s %s (%s)\n", status, c.Name, c.Image)
			shown++
		}
	}

	fmt.Println()
}

func checkPort5432Owner() {
	fmt.Println(subtitleStyle.Render("Port 5432 Owner"))
	fmt.Println()

	// Use lsof to find what's listening on 5432
	lsofCmd := exec.Command("lsof", "-i", ":5432", "-sTCP:LISTEN")
	output, err := lsofCmd.Output()

	if err != nil || len(output) == 0 {
		fmt.Printf("  %s Nothing listening on port 5432\n", warningStyle.Render("●"))
		fmt.Println()
		return
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) < 2 {
		fmt.Printf("  %s Could not determine port owner\n", warningStyle.Render("●"))
		fmt.Println()
		return
	}

	// Parse lsof output - skip header
	for _, line := range lines[1:] {
		fields := strings.Fields(line)
		if len(fields) >= 1 {
			processName := fields[0]
			pid := ""
			if len(fields) >= 2 {
				pid = fields[1]
			}

			// Identify the process
			switch {
			case strings.Contains(processName, "OrbStack"):
				fmt.Printf("  %s OrbStack (PID %s) is handling port 5432\n", successStyle.Render("●"), pid)
				fmt.Printf("    %s OrbStack routes to its own containers, NOT Docker Desktop\n", infoStyle.Render("→"))
			case strings.Contains(processName, "com.docke") || strings.Contains(processName, "Docker"):
				fmt.Printf("  %s Docker Desktop (PID %s) is handling port 5432\n", successStyle.Render("●"), pid)
			case strings.Contains(processName, "postgres"):
				fmt.Printf("  %s Native PostgreSQL (PID %s) is handling port 5432\n", successStyle.Render("●"), pid)
			default:
				fmt.Printf("  %s %s (PID %s) is handling port 5432\n", infoStyle.Render("●"), processName, pid)
			}
		}
	}
	fmt.Println()
}

func checkContainerEnvironment() {
	fmt.Println(subtitleStyle.Render("Container Environment"))
	fmt.Println()

	// Check if OrbStack is running
	orbCmd := exec.Command("pgrep", "-x", "OrbStack")
	orbOutput, _ := orbCmd.Output()
	orbRunning := len(strings.TrimSpace(string(orbOutput))) > 0

	// Check if Docker Desktop is running
	dockerDesktopCmd := exec.Command("pgrep", "-f", "Docker Desktop")
	dockerOutput, _ := dockerDesktopCmd.Output()
	dockerRunning := len(strings.TrimSpace(string(dockerOutput))) > 0

	// Check if Podman is available
	podmanCmd := exec.Command("which", "podman")
	podmanOutput, _ := podmanCmd.Output()
	podmanAvailable := len(strings.TrimSpace(string(podmanOutput))) > 0

	// Check if Podman machine is running
	podmanRunning := false
	if podmanAvailable {
		podmanMachineCmd := exec.Command("podman", "machine", "list", "--format", "{{.Running}}")
		machineOutput, err := podmanMachineCmd.Output()
		if err == nil && strings.Contains(string(machineOutput), "true") {
			podmanRunning = true
		}
	}

	runtimes := []string{}
	if orbRunning {
		runtimes = append(runtimes, "OrbStack")
	}
	if dockerRunning {
		runtimes = append(runtimes, "Docker Desktop")
	}
	if podmanRunning {
		runtimes = append(runtimes, "Podman")
	}

	if len(runtimes) > 1 {
		fmt.Printf("  %s MULTIPLE RUNTIMES DETECTED: %s\n", warningStyle.Render("⚠"), strings.Join(runtimes, ", "))
		fmt.Printf("    %s This can cause confusion about which containers are active\n", warningStyle.Render("→"))
		if orbRunning {
			fmt.Printf("    %s OrbStack typically takes precedence for port bindings\n", infoStyle.Render("→"))
		}
	} else if orbRunning {
		fmt.Printf("  %s OrbStack is running\n", successStyle.Render("●"))
		fmt.Printf("    %s Use 'orb' or 'docker' commands - OrbStack provides docker compatibility\n", infoStyle.Render("→"))
	} else if dockerRunning {
		fmt.Printf("  %s Docker Desktop is running\n", successStyle.Render("●"))
	} else if podmanRunning {
		fmt.Printf("  %s Podman is running\n", successStyle.Render("●"))
		fmt.Printf("    %s Using podman as docker replacement\n", infoStyle.Render("→"))
	} else if podmanAvailable {
		fmt.Printf("  %s Podman available but not running\n", warningStyle.Render("●"))
		fmt.Printf("    %s Run 'podman machine start' to start\n", infoStyle.Render("→"))
	} else {
		fmt.Printf("  %s No container runtime detected\n", errorStyle.Render("●"))
	}

	fmt.Println()
}

func checkPostgresViaRails() {
	fmt.Println(subtitleStyle.Render("PostgreSQL (via Rails)"))
	fmt.Println()

	// Use Rails to query the database - this is the authoritative source
	// Use actual newline, not escaped
	railsCmd := exec.Command("bin/rails", "runner",
		`puts ActiveRecord::Base.connection.execute('SELECT datname FROM pg_database').map{|r| r["datname"]}.join("\n")`)
	output, err := railsCmd.Output()

	if err != nil {
		// Try with bundle exec
		railsCmd = exec.Command("bundle", "exec", "rails", "runner",
			`puts ActiveRecord::Base.connection.execute('SELECT datname FROM pg_database').map{|r| r["datname"]}.join("\n")`)
		output, err = railsCmd.Output()
	}

	if err != nil {
		fmt.Printf("  %s Cannot connect via Rails (%s)\n", errorStyle.Render("●"), err.Error())
		fmt.Println()
		// Fall back to trying docker containers directly
		checkPostgresFallback()
		return
	}

	fmt.Printf("  %s Connected to PostgreSQL\n", successStyle.Render("●"))

	// Get current database name
	dbCmd := exec.Command("bin/rails", "runner",
		"puts ActiveRecord::Base.connection.execute('SELECT current_database()').first['current_database']")
	dbOutput, _ := dbCmd.Output()
	currentDb := strings.TrimSpace(string(dbOutput))
	if currentDb != "" {
		fmt.Printf("  %s Current database: %s\n", infoStyle.Render("→"), currentDb)
	}

	// Parse databases
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	vulcanDbs := []string{}
	otherDbs := []string{}

	for _, dbName := range lines {
		dbName = strings.TrimSpace(dbName)
		if dbName == "" || dbName == "template0" || dbName == "template1" || dbName == "postgres" {
			continue
		}
		if strings.Contains(dbName, "vulcan") {
			vulcanDbs = append(vulcanDbs, dbName)
		} else {
			otherDbs = append(otherDbs, dbName)
		}
	}

	if len(vulcanDbs) > 0 {
		fmt.Println()
		fmt.Println("  Vulcan databases:")
		for _, db := range vulcanDbs {
			marker := "•"
			if db == currentDb {
				marker = "▶"
			}
			fmt.Printf("    %s %s\n", successStyle.Render(marker), db)
		}
	}

	if len(otherDbs) > 0 {
		fmt.Println()
		fmt.Println("  Other databases:")
		for _, db := range otherDbs {
			fmt.Printf("    %s %s\n", infoStyle.Render("•"), db)
		}
	}

	fmt.Println()
}

func checkPostgresFallback() {
	// Try common docker container names for postgres
	containers := []string{
		"vulcan-clean-db-1",
		"vulcan-db-1",
		"heimdall-clean-database-1",
		"postgres",
	}

	for _, container := range containers {
		dockerCmd := exec.Command("docker", "exec", "-e", "PGPASSWORD=postgres", container,
			"psql", "-U", "postgres", "-c", "\\l", "-t")
		output, err := dockerCmd.Output()
		if err == nil {
			fmt.Printf("  %s Found PostgreSQL in container: %s\n", successStyle.Render("●"), container)

			// Check for vulcan databases
			hasVulcan := false
			lines := strings.Split(string(output), "\n")
			for _, line := range lines {
				if strings.Contains(line, "vulcan") {
					hasVulcan = true
					break
				}
			}

			if !hasVulcan {
				fmt.Printf("    %s WARNING: No vulcan databases found in this container!\n", warningStyle.Render("⚠"))
				fmt.Printf("    %s Rails may be connecting to a different postgres instance\n", warningStyle.Render("→"))
			}
			return
		}
	}

	fmt.Printf("  %s Could not find PostgreSQL in any known container\n", warningStyle.Render("●"))
}

func checkPostgres() {
	fmt.Println(subtitleStyle.Render("PostgreSQL"))
	fmt.Println()

	// Try to connect and list databases
	psqlCmd := exec.Command("psql", "-h", "127.0.0.1", "-U", "postgres", "-c", "\\l", "-t")
	psqlCmd.Env = append(psqlCmd.Environ(), "PGPASSWORD=postgres")
	output, err := psqlCmd.Output()

	if err != nil {
		// Try via docker
		dockerCmd := exec.Command("docker", "exec", "-e", "PGPASSWORD=postgres", "-i",
			"heimdall-clean-database-1", "psql", "-U", "postgres", "-c", "\\l", "-t")
		output, err = dockerCmd.Output()
	}

	if err != nil {
		fmt.Printf("  %s PostgreSQL (not accessible)\n", errorStyle.Render("●"))
		fmt.Println()
		return
	}

	fmt.Printf("  %s PostgreSQL running on port 5432\n", successStyle.Render("●"))

	// Parse databases
	lines := strings.Split(string(output), "\n")
	vulcanDbs := []string{}
	otherDbs := []string{}

	for _, line := range lines {
		parts := strings.Split(line, "|")
		if len(parts) > 0 {
			dbName := strings.TrimSpace(parts[0])
			if dbName == "" || dbName == "template0" || dbName == "template1" || dbName == "postgres" {
				continue
			}
			if strings.Contains(dbName, "vulcan") {
				vulcanDbs = append(vulcanDbs, dbName)
			} else {
				otherDbs = append(otherDbs, dbName)
			}
		}
	}

	if len(vulcanDbs) > 0 {
		fmt.Println()
		fmt.Println("  Vulcan databases:")
		for _, db := range vulcanDbs {
			fmt.Printf("    %s %s\n", successStyle.Render("•"), db)
		}
	}

	if len(otherDbs) > 0 {
		fmt.Println()
		fmt.Println("  Other databases:")
		for _, db := range otherDbs {
			fmt.Printf("    %s %s\n", infoStyle.Render("•"), db)
		}
	}

	fmt.Println()
}

func checkDockerServices(projectRoot string) {
	fmt.Println(subtitleStyle.Render("Docker Containers"))
	fmt.Println()

	// Get all running containers
	dockerCmd := exec.Command("docker", "ps", "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}")
	output, err := dockerCmd.Output()

	if err != nil {
		printInfo("Docker not accessible")
		fmt.Println()
		return
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 0 || (len(lines) == 1 && lines[0] == "") {
		printInfo("No containers running")
		fmt.Println()
		return
	}

	// Categorize containers
	relevant := []string{}
	other := []string{}

	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) < 3 {
			continue
		}
		name := parts[0]
		image := parts[1]
		status := parts[2]
		ports := ""
		if len(parts) >= 4 {
			ports = parts[3]
		}

		// Check if relevant to Vulcan (postgres, redis, vulcan)
		isRelevant := strings.Contains(strings.ToLower(name), "vulcan") ||
			strings.Contains(strings.ToLower(name), "postgres") ||
			strings.Contains(strings.ToLower(image), "postgres") ||
			strings.Contains(strings.ToLower(name), "redis") ||
			strings.Contains(strings.ToLower(image), "redis")

		display := fmt.Sprintf("%s (%s)", name, image)
		if ports != "" && (strings.Contains(ports, "5432") || strings.Contains(ports, "6379")) {
			display = fmt.Sprintf("%s [%s]", display, ports)
		}

		if strings.Contains(status, "healthy") {
			display = fmt.Sprintf("%s %s", successStyle.Render("●"), display)
		} else if strings.Contains(status, "Up") {
			display = fmt.Sprintf("%s %s", successStyle.Render("●"), display)
		} else {
			display = fmt.Sprintf("%s %s", errorStyle.Render("●"), display)
		}

		if isRelevant {
			relevant = append(relevant, display)
		} else {
			other = append(other, display)
		}
	}

	if len(relevant) > 0 {
		fmt.Println("  Relevant:")
		for _, c := range relevant {
			fmt.Printf("    %s\n", c)
		}
	}

	if len(other) > 0 {
		fmt.Println("  Other:")
		for _, c := range other {
			fmt.Printf("    %s\n", c)
		}
	}

	fmt.Println()
}

func parseDockerPS(output []byte, services map[string]string, prefix string) {
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		var container struct {
			Name   string `json:"Name"`
			State  string `json:"State"`
			Status string `json:"Status"`
		}
		if err := json.Unmarshal([]byte(line), &container); err == nil && container.Name != "" {
			services[container.Name] = container.State
		}
	}
}

func checkHealthEndpoints() {
	fmt.Println(subtitleStyle.Render("Health Checks"))
	fmt.Println()

	// Try common ports - 5000 for dev (foreman), 3000 for production
	ports := []string{"5000", "3000"}
	var workingPort string

	client := &http.Client{Timeout: 2 * time.Second}
	for _, port := range ports {
		resp, err := client.Get("http://localhost:" + port + "/up")
		if err == nil {
			resp.Body.Close()
			workingPort = port
			break
		}
	}

	if workingPort == "" {
		fmt.Printf("  %s Rails App (not responding on ports 3000 or 5000)\n", errorStyle.Render("●"))
		fmt.Println()
		return
	}

	endpoints := []struct {
		name string
		path string
	}{
		{"Rails App", "/up"},
		{"Health Check", "/health_check"},
	}

	fmt.Printf("  Port: %s\n", infoStyle.Render(workingPort))

	for _, ep := range endpoints {
		url := "http://localhost:" + workingPort + ep.path
		resp, err := client.Get(url)
		if err != nil {
			fmt.Printf("  %s %s (not responding)\n", errorStyle.Render("●"), ep.name)
			continue
		}
		resp.Body.Close()

		if resp.StatusCode == 200 {
			fmt.Printf("  %s %s\n", successStyle.Render("●"), ep.name)
		} else {
			fmt.Printf("  %s %s (status: %d)\n", errorStyle.Render("●"), ep.name, resp.StatusCode)
		}
	}
	fmt.Println()
}
