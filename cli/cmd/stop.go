package cmd

import (
	"os/exec"

	"github.com/spf13/cobra"
)

var stopCmd = &cobra.Command{
	Use:   "stop",
	Short: "Stop Vulcan services",
	Long:  `Stop all running Vulcan services (Docker containers).`,
	Run:   runStop,
}

var (
	stopAll bool
)

func init() {
	rootCmd.AddCommand(stopCmd)
	stopCmd.Flags().BoolVarP(&stopAll, "all", "a", false, "Stop all services including dev database")
}

func runStop(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	printTitle("Stopping Vulcan")

	// Stop production containers
	prodCmd := exec.Command("docker", "compose", "down")
	prodCmd.Dir = projectRoot
	prodCmd.Run()

	if stopAll {
		// Also stop dev database
		devCmd := exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "down")
		devCmd.Dir = projectRoot
		devCmd.Run()
		printSuccess("All services stopped (including dev database)")
	} else {
		printSuccess("Services stopped")
		printInfo("Dev database still running. Use --all to stop everything.")
	}
}
