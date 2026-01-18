package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

var startCmd = &cobra.Command{
	Use:   "start",
	Short: "Start Vulcan services",
	Long: `Start Vulcan services for development or production.

Development mode starts Rails and asset watcher using foreman.
Production mode starts Docker containers.`,
	Run: runStart,
}

var (
	startDaemon bool
)

func init() {
	rootCmd.AddCommand(startCmd)
	startCmd.Flags().BoolVarP(&startDaemon, "daemon", "d", false, "Run in background (production only)")
}

func runStart(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	// Detect environment
	env := detectEnvironment(projectRoot)

	if env == "development" {
		startDevelopment(projectRoot)
	} else {
		startProduction(projectRoot)
	}
}

func detectEnvironment(projectRoot string) string {
	// Check if .env exists and has production settings
	envPath := projectRoot + "/.env"
	if data, err := os.ReadFile(envPath); err == nil {
		content := string(data)
		if strings.Contains(content, "RAILS_ENV=production") {
			return "production"
		}
	}

	// Check if docker-compose.yml has web service built
	// Default to development
	return "development"
}


func startDevelopment(projectRoot string) {
	printTitle("Starting Vulcan (Development)")

	// Check if PostgreSQL is running
	checkCmd := exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "ps", "--services", "--filter", "status=running")
	checkCmd.Dir = projectRoot
	output, _ := checkCmd.Output()

	if !strings.Contains(string(output), "db") {
		printInfo("Starting PostgreSQL...")
		dbCmd := exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "up", "-d")
		dbCmd.Dir = projectRoot
		if err := dbCmd.Run(); err != nil {
			printError("Failed to start PostgreSQL: " + err.Error())
			os.Exit(1)
		}
		printSuccess("PostgreSQL started")
	} else {
		printSuccess("PostgreSQL already running")
	}

	fmt.Println()
	printInfo("Starting Rails and asset watcher...")
	printInfo("Access Vulcan at http://localhost:3000")
	printInfo("Press Ctrl+C to stop\n")

	// Start foreman
	foremanCmd := exec.Command("foreman", "start", "-f", "Procfile.dev")
	foremanCmd.Dir = projectRoot
	foremanCmd.Stdout = os.Stdout
	foremanCmd.Stderr = os.Stderr
	foremanCmd.Stdin = os.Stdin
	foremanCmd.Run()
}

func startProduction(projectRoot string) {
	printTitle("Starting Vulcan (Production)")

	args := []string{"compose", "up"}
	if startDaemon {
		args = append(args, "-d")
	}

	dockerCmd := exec.Command("docker", args...)
	dockerCmd.Dir = projectRoot
	dockerCmd.Stdout = os.Stdout
	dockerCmd.Stderr = os.Stderr
	dockerCmd.Stdin = os.Stdin

	if err := dockerCmd.Run(); err != nil {
		printError("Failed to start services: " + err.Error())
		os.Exit(1)
	}

	if startDaemon {
		printSuccess("Vulcan started in background")
		printInfo("View logs with: vulcan logs")
		printInfo("Check status with: vulcan status")
	}
}
