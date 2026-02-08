package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var (
	// Styles
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7C3AED")).
			MarginBottom(1)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#6B7280"))

	successStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#10B981"))

	errorStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#EF4444"))

	warningStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#F59E0B"))

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#3B82F6"))
)

var rootCmd = &cobra.Command{
	Use:   "vulcan",
	Short: "Vulcan CLI - STIG authoring made simple",
	Long: titleStyle.Render("Vulcan CLI") + "\n" +
		subtitleStyle.Render("Streamline STIG-ready security guidance documentation") + "\n\n" +
		"Vulcan helps security teams create STIG-ready security guidance\n" +
		"documentation and InSpec automated validation profiles.\n\n" +
		"Commands:\n" +
		"  setup       Interactive setup wizard for dev or production\n" +
		"  start       Start Vulcan services\n" +
		"  stop        Stop Vulcan services\n" +
		"  status      Show service status and health\n" +
		"  logs        View service logs\n" +
		"  build       Build Docker images\n" +
		"  test        Run test suite\n" +
		"  db          Database management commands\n" +
		"  config      View and manage configuration\n\n" +
		"Configuration:\n" +
		"  Vulcan CLI loads configuration from multiple sources (lowest to highest priority):\n" +
		"  1. Built-in defaults\n" +
		"  2. vulcan.yaml (or .json, .toml) in project root\n" +
		"  3. .env file\n" +
		"  4. Environment variables (VULCAN_* prefix)\n" +
		"  5. Command-line flags\n\n" +
		"Examples:\n" +
		"  vulcan setup dev              # Set up development environment\n" +
		"  vulcan start                  # Start services\n" +
		"  vulcan build --info           # Show build configuration\n" +
		"  vulcan db backup              # Create database backup\n" +
		"  vulcan config show            # View current configuration\n",
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	cobra.OnInitialize(InitConfig)
	rootCmd.CompletionOptions.DisableDefaultCmd = true

	// Set CLI version (enables `vulcan --version`)
	projectRoot := GetProjectRoot()
	cliVersion := getCLIVersion(projectRoot)
	appVersion := getProjectVersion(projectRoot)
	rootCmd.Version = fmt.Sprintf("%s (Vulcan %s)", cliVersion, appVersion)

	AddConfigFlags(rootCmd)
}

// Helper functions for output
func printSuccess(msg string) {
	fmt.Println(successStyle.Render("✓ " + msg))
}

func printError(msg string) {
	fmt.Println(errorStyle.Render("✗ " + msg))
}

func printInfo(msg string) {
	fmt.Println(infoStyle.Render("→ " + msg))
}

func printTitle(msg string) {
	fmt.Println(titleStyle.Render(msg))
}

// getCLIVersion reads the CLI's own VERSION file from cli/VERSION.
// Falls back to "dev" if the file is missing or unreadable.
func getCLIVersion(projectRoot string) string {
	// When running from project root, cli/VERSION exists
	// When running from cli/ subdirectory, VERSION is in current dir
	paths := []string{
		filepath.Join(projectRoot, "cli", "VERSION"),
		"VERSION",
	}
	for _, p := range paths {
		if data, err := os.ReadFile(p); err == nil {
			if v := strings.TrimSpace(string(data)); v != "" {
				return v
			}
		}
	}
	return "dev"
}

// getProjectVersion reads the app VERSION file from the project root.
// Falls back to "dev" if the file is missing or unreadable.
func getProjectVersion(projectRoot string) string {
	data, err := os.ReadFile(filepath.Join(projectRoot, "VERSION"))
	if err != nil {
		return "dev"
	}
	if v := strings.TrimSpace(string(data)); v != "" {
		return v
	}
	return "dev"
}

// GetProjectRoot returns the Vulcan project root directory
func GetProjectRoot() string {
	// First check if we're in the cli subdirectory
	if _, err := os.Stat("../Gemfile"); err == nil {
		return ".."
	}
	// Check current directory
	if _, err := os.Stat("Gemfile"); err == nil {
		return "."
	}
	// Default to current directory
	return "."
}
