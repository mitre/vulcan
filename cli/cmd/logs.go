package cmd

import (
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var logsCmd = &cobra.Command{
	Use:   "logs [service]",
	Short: "View service logs",
	Long: `View logs from Vulcan services.

Examples:
  vulcan logs           # All services
  vulcan logs web       # Web service only
  vulcan logs db        # Database only
  vulcan logs -f        # Follow logs`,
	Run: runLogs,
}

var (
	logsFollow bool
	logsTail   string
)

func init() {
	rootCmd.AddCommand(logsCmd)
	logsCmd.Flags().BoolVarP(&logsFollow, "follow", "f", false, "Follow log output")
	logsCmd.Flags().StringVarP(&logsTail, "tail", "n", "100", "Number of lines to show")
}

func runLogs(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	dockerArgs := []string{"compose", "logs"}

	if logsFollow {
		dockerArgs = append(dockerArgs, "-f")
	}

	dockerArgs = append(dockerArgs, "--tail", logsTail)

	// Add specific service if provided
	if len(args) > 0 {
		dockerArgs = append(dockerArgs, args[0])
	}

	dockerCmd := exec.Command("docker", dockerArgs...)
	dockerCmd.Dir = projectRoot
	dockerCmd.Stdout = os.Stdout
	dockerCmd.Stderr = os.Stderr
	dockerCmd.Stdin = os.Stdin
	dockerCmd.Run()
}
