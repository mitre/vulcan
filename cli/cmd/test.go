package cmd

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var testCmd = &cobra.Command{
	Use:   "test [type]",
	Short: "Run tests",
	Long: `Run the Vulcan test suite.

Examples:
  vulcan test           # Run all tests
  vulcan test backend   # Run RSpec tests only
  vulcan test frontend  # Run Vitest tests only
  vulcan test --watch   # Run frontend tests in watch mode`,
	Run: runTest,
}

var (
	testWatch    bool
	testParallel bool
)

func init() {
	rootCmd.AddCommand(testCmd)
	testCmd.Flags().BoolVarP(&testWatch, "watch", "w", false, "Watch mode (frontend only)")
	testCmd.Flags().BoolVar(&testParallel, "parallel", true, "Run backend tests in parallel")
}

func runTest(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	testType := "all"
	if len(args) > 0 {
		testType = args[0]
	}

	switch testType {
	case "backend", "rspec", "ruby":
		runBackendTests(projectRoot)
	case "frontend", "vitest", "js":
		runFrontendTests(projectRoot)
	default:
		runAllTests(projectRoot)
	}
}

func runBackendTests(projectRoot string) {
	printTitle("Running Backend Tests (RSpec)")
	fmt.Println()

	var testCmd *exec.Cmd
	if testParallel {
		testCmd = exec.Command("bundle", "exec", "parallel_rspec", "spec/")
	} else {
		testCmd = exec.Command("bundle", "exec", "rspec")
	}

	testCmd.Dir = projectRoot
	testCmd.Stdout = os.Stdout
	testCmd.Stderr = os.Stderr

	if err := testCmd.Run(); err != nil {
		printError("Backend tests failed")
		os.Exit(1)
	}
	printSuccess("Backend tests passed")
}

func runFrontendTests(projectRoot string) {
	printTitle("Running Frontend Tests (Vitest)")
	fmt.Println()

	args := []string{"vitest"}
	if !testWatch {
		args = append(args, "run")
	}

	testCmd := exec.Command("pnpm", args...)
	testCmd.Dir = projectRoot
	testCmd.Stdout = os.Stdout
	testCmd.Stderr = os.Stderr
	testCmd.Stdin = os.Stdin

	if err := testCmd.Run(); err != nil {
		if !testWatch {
			printError("Frontend tests failed")
			os.Exit(1)
		}
	}
	if !testWatch {
		printSuccess("Frontend tests passed")
	}
}

func runAllTests(projectRoot string) {
	printTitle("Running All Tests")
	fmt.Println()

	// Run frontend tests first (faster)
	printInfo("Frontend tests...")
	frontendCmd := exec.Command("pnpm", "vitest", "run")
	frontendCmd.Dir = projectRoot
	frontendCmd.Stdout = os.Stdout
	frontendCmd.Stderr = os.Stderr

	if err := frontendCmd.Run(); err != nil {
		printError("Frontend tests failed")
		os.Exit(1)
	}
	printSuccess("Frontend tests passed")

	fmt.Println()

	// Run backend tests
	printInfo("Backend tests...")
	var backendCmd *exec.Cmd
	if testParallel {
		backendCmd = exec.Command("bundle", "exec", "parallel_rspec", "spec/")
	} else {
		backendCmd = exec.Command("bundle", "exec", "rspec")
	}

	backendCmd.Dir = projectRoot
	backendCmd.Stdout = os.Stdout
	backendCmd.Stderr = os.Stderr

	if err := backendCmd.Run(); err != nil {
		printError("Backend tests failed")
		os.Exit(1)
	}
	printSuccess("Backend tests passed")

	fmt.Println()
	printSuccess("All tests passed!")
}
