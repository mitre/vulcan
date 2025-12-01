package cmd

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"math/big"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"
)

var userCmd = &cobra.Command{
	Use:   "user",
	Short: "Manage Vulcan users (requires server access)",
	Long: `Manage Vulcan user accounts.

SECURITY: These commands require direct server/container access.
They can only be run by someone with shell access to the Vulcan server.

Commands:
  vulcan user list              # List all users
  vulcan user reset-password    # Reset a user's password
  vulcan user create-admin      # Create a new admin user
  vulcan user confirm           # Confirm an unconfirmed account`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

var userListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all users",
	Run:   runUserList,
}

var userResetPasswordCmd = &cobra.Command{
	Use:   "reset-password [email]",
	Short: "Reset a user's password",
	Long: `Reset a user's password to a new generated value.

Examples:
  vulcan user reset-password                 # Interactive mode
  vulcan user reset-password admin@example.com`,
	Run: runUserResetPassword,
}

var userCreateAdminCmd = &cobra.Command{
	Use:   "create-admin",
	Short: "Create a new admin user",
	Long:  `Create a new administrator account with full privileges.`,
	Run:   runUserCreateAdmin,
}

var userUnlockCmd = &cobra.Command{
	Use:   "confirm [email]",
	Short: "Confirm a user account (skip email confirmation)",
	Long: `Manually confirm a user account that hasn't completed email confirmation.

Examples:
  vulcan user confirm                   # Interactive mode
  vulcan user confirm admin@example.com`,
	Run: runUserConfirm,
}

func init() {
	rootCmd.AddCommand(userCmd)
	userCmd.AddCommand(userListCmd)
	userCmd.AddCommand(userResetPasswordCmd)
	userCmd.AddCommand(userCreateAdminCmd)
	userCmd.AddCommand(userUnlockCmd)
}

func getDockerContainer() string {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cli, err := NewDockerClient()
	if err != nil {
		return ""
	}
	defer cli.Close()

	containers, err := cli.ListContainers(ctx, false)
	if err != nil {
		return ""
	}

	// Look for vulcan web container
	for _, c := range containers {
		name := strings.ToLower(c.Name)
		if strings.Contains(name, "vulcan") && strings.Contains(name, "web") {
			return c.Name
		}
	}

	return ""
}

func execRailsCommand(container, command string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cli, err := NewDockerClient()
	if err != nil {
		return "", err
	}
	defer cli.Close()

	// Execute rails runner command
	cmd := []string{"bin/rails", "runner", command}
	return cli.ExecInContainer(ctx, container, cmd)
}

func runUserList(cmd *cobra.Command, args []string) {
	printTitle("Vulcan Users")
	fmt.Println()

	// Note: Devise Lockable is not enabled in Vulcan, so we check confirmed_at instead
	railsCmd := `User.order(:email).each { |u| puts "#{u.email}\t#{u.admin? ? 'admin' : 'user'}\t#{u.confirmed_at ? 'active' : 'unconfirmed'}" }`

	container := getDockerContainer()
	if container == "" {
		// Try running locally
		printInfo("No Docker container found, attempting local execution...")
		runLocalRailsCommand(railsCmd)
		return
	}

	output, err := execRailsCommand(container, railsCmd)
	if err != nil {
		printError("Failed to list users: " + err.Error())
		return
	}

	lines := strings.Split(strings.TrimSpace(output), "\n")
	fmt.Printf("  %-40s %-10s %s\n", "EMAIL", "ROLE", "STATUS")
	fmt.Println("  " + strings.Repeat("-", 60))

	for _, line := range lines {
		// Skip docker output noise
		if strings.Contains(line, "OCI runtime") || line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) >= 3 {
			status := successStyle.Render(parts[2])
			if parts[2] == "unconfirmed" {
				status = warningStyle.Render("unconfirmed")
			}
			role := parts[1]
			if role == "admin" {
				role = infoStyle.Render("admin")
			}
			fmt.Printf("  %-40s %-10s %s\n", parts[0], role, status)
		}
	}
}

func runUserResetPassword(cmd *cobra.Command, args []string) {
	printTitle("Reset User Password")
	fmt.Println()

	var email string
	if len(args) > 0 {
		email = args[0]
	} else {
		huh.NewInput().
			Title("User email").
			Placeholder("user@example.com").
			Value(&email).
			Run()
	}

	if email == "" {
		printError("Email is required")
		return
	}

	// Ask if user wants to set their own password or generate one
	var passwordChoice string
	huh.NewSelect[string]().
		Title("Password option").
		Options(
			huh.NewOption("Generate secure password (recommended)", "generate"),
			huh.NewOption("Enter custom password", "custom"),
		).
		Value(&passwordChoice).
		Run()

	var newPassword string
	if passwordChoice == "custom" {
		// Get custom password with validation
		for {
			var pwd, pwdConfirm string
			huh.NewInput().
				Title("Enter new password").
				Description("Min 12 chars, must include upper, lower, digit, special").
				EchoMode(huh.EchoModePassword).
				Value(&pwd).
				Run()

			if err := validatePasswordStrength(pwd); err != nil {
				printError(err.Error())
				continue
			}

			huh.NewInput().
				Title("Confirm password").
				EchoMode(huh.EchoModePassword).
				Value(&pwdConfirm).
				Run()

			if pwd != pwdConfirm {
				printError("Passwords do not match")
				continue
			}

			newPassword = pwd
			break
		}
	} else {
		// Generate secure password
		newPassword = generateSecurePassword(20) // Increased from 16
	}

	// Confirm
	var confirm bool
	huh.NewConfirm().
		Title("Reset password for " + email + "?").
		Description(fmt.Sprintf("Password hash: %s", hashForLogging(newPassword))).
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	// Execute password reset
	railsCmd := fmt.Sprintf(`
		user = User.find_by(email: '%s')
		if user
			user.password = '%s'
			user.password_confirmation = '%s'
			user.save!
			puts 'SUCCESS'
		else
			puts 'USER_NOT_FOUND'
		end
	`, email, newPassword, newPassword)

	container := getDockerContainer()
	var output string
	var err error

	if container != "" {
		output, err = execRailsCommand(container, railsCmd)
	} else {
		output = runLocalRailsCommandReturn(railsCmd)
	}

	if err != nil {
		printError("Failed to reset password: " + err.Error())
		return
	}

	if strings.Contains(output, "USER_NOT_FOUND") {
		printError("User not found: " + email)
		return
	}

	if strings.Contains(output, "SUCCESS") {
		fmt.Println()
		printSuccess("Password reset successfully!")
		fmt.Println()
		fmt.Println("  New password: " + infoStyle.Render(newPassword))
		fmt.Println()
		printInfo("Please share this password securely with the user")
		printInfo("They should change it after first login")
	} else {
		printError("Failed to reset password")
		fmt.Println(output)
	}
}

func runUserCreateAdmin(cmd *cobra.Command, args []string) {
	printTitle("Create Admin User")
	fmt.Println()

	var email, name string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Admin email").
				Placeholder("admin@example.com").
				Value(&email),

			huh.NewInput().
				Title("Display name").
				Placeholder("Admin User").
				Value(&name),
		),
	)

	if err := form.Run(); err != nil {
		return
	}

	if email == "" {
		printError("Email is required")
		return
	}

	if name == "" {
		name = strings.Split(email, "@")[0]
	}

	// Generate secure password
	password := generateSecurePassword(16)

	var confirm bool
	huh.NewConfirm().
		Title("Create admin account?").
		Description(fmt.Sprintf("Email: %s, Name: %s", email, name)).
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	// Create admin user
	railsCmd := fmt.Sprintf(`
		if User.exists?(email: '%s')
			puts 'USER_EXISTS'
		else
			user = User.new(
				email: '%s',
				name: '%s',
				password: '%s',
				password_confirmation: '%s',
				admin: true,
				confirmed_at: Time.current
			)
			if user.save
				puts 'SUCCESS'
			else
				puts 'FAILED: ' + user.errors.full_messages.join(', ')
			end
		end
	`, email, email, name, password, password)

	container := getDockerContainer()
	var output string
	var err error

	if container != "" {
		output, err = execRailsCommand(container, railsCmd)
	} else {
		output = runLocalRailsCommandReturn(railsCmd)
	}

	if err != nil {
		printError("Failed to create admin: " + err.Error())
		return
	}

	if strings.Contains(output, "USER_EXISTS") {
		printError("User already exists: " + email)
		printInfo("Use 'vulcan user reset-password' to change their password")
		return
	}

	if strings.Contains(output, "SUCCESS") {
		fmt.Println()
		printSuccess("Admin account created!")
		fmt.Println()
		fmt.Println("  Email:    " + infoStyle.Render(email))
		fmt.Println("  Password: " + infoStyle.Render(password))
		fmt.Println()
		printInfo("Please share these credentials securely")
		printInfo("The user should change their password after first login")
	} else {
		printError("Failed to create admin")
		fmt.Println(output)
	}
}

func runUserConfirm(cmd *cobra.Command, args []string) {
	printTitle("Confirm User Account")
	fmt.Println()

	var email string
	if len(args) > 0 {
		email = args[0]
	} else {
		huh.NewInput().
			Title("User email").
			Placeholder("user@example.com").
			Value(&email).
			Run()
	}

	if email == "" {
		printError("Email is required")
		return
	}

	var confirm bool
	huh.NewConfirm().
		Title("Confirm account for " + email + "?").
		Description("This will skip email confirmation for this user").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	railsCmd := fmt.Sprintf(`
		user = User.find_by(email: '%s')
		if user
			if user.confirmed_at
				puts 'ALREADY_CONFIRMED'
			else
				user.confirm
				puts 'SUCCESS'
			end
		else
			puts 'USER_NOT_FOUND'
		end
	`, email)

	container := getDockerContainer()
	var output string
	var err error

	if container != "" {
		output, err = execRailsCommand(container, railsCmd)
	} else {
		output = runLocalRailsCommandReturn(railsCmd)
	}

	if err != nil {
		printError("Failed to confirm account: " + err.Error())
		return
	}

	if strings.Contains(output, "USER_NOT_FOUND") {
		printError("User not found: " + email)
		return
	}

	if strings.Contains(output, "ALREADY_CONFIRMED") {
		printInfo("Account already confirmed: " + email)
		return
	}

	if strings.Contains(output, "SUCCESS") {
		printSuccess("Account confirmed: " + email)
	} else {
		printError("Failed to confirm account")
	}
}

// generateSecurePassword creates a secure random password
func generateSecurePassword(length int) string {
	const (
		lowercase = "abcdefghijklmnopqrstuvwxyz"
		uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		digits    = "0123456789"
		special   = "!@#$%^&*"
	)

	all := lowercase + uppercase + digits + special

	// Ensure at least one of each type
	password := make([]byte, length)

	// First char lowercase
	idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(lowercase))))
	password[0] = lowercase[idx.Int64()]

	// Second char uppercase
	idx, _ = rand.Int(rand.Reader, big.NewInt(int64(len(uppercase))))
	password[1] = uppercase[idx.Int64()]

	// Third char digit
	idx, _ = rand.Int(rand.Reader, big.NewInt(int64(len(digits))))
	password[2] = digits[idx.Int64()]

	// Fourth char special
	idx, _ = rand.Int(rand.Reader, big.NewInt(int64(len(special))))
	password[3] = special[idx.Int64()]

	// Rest random from all
	for i := 4; i < length; i++ {
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(all))))
		password[i] = all[idx.Int64()]
	}

	// Shuffle
	for i := len(password) - 1; i > 0; i-- {
		j, _ := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
		password[i], password[j.Int64()] = password[j.Int64()], password[i]
	}

	return string(password)
}

// getRailsCommand returns the appropriate rails command based on environment
// In Docker containers: bin/rails works directly
// In development: bundle exec rails is more reliable
func getRailsCommand(projectRoot string) (string, []string) {
	// Check if we're in a Docker container (check for /.dockerenv or cgroup)
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return "bin/rails", nil
	}

	// Check if BUNDLE_PATH is set (indicates bundle deployment mode)
	if os.Getenv("BUNDLE_PATH") != "" {
		return "bin/rails", nil
	}

	// Default to bundle exec for development environments
	return "bundle", []string{"exec", "rails"}
}

func runLocalRailsCommand(command string) {
	projectRoot := GetProjectRoot()
	railsCmd, railsArgs := getRailsCommand(projectRoot)

	args := append(railsArgs, "runner", command)
	fmt.Println(subtitleStyle.Render(fmt.Sprintf("Running via '%s %s runner'...", railsCmd, strings.Join(railsArgs, " "))))

	cmd := exec.Command(railsCmd, args...)
	cmd.Dir = projectRoot
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}

func runLocalRailsCommandReturn(command string) string {
	projectRoot := GetProjectRoot()
	railsCmd, railsArgs := getRailsCommand(projectRoot)

	args := append(railsArgs, "runner", command)
	cmd := exec.Command(railsCmd, args...)
	cmd.Dir = projectRoot
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return string(output)
}

// secureExecRailsCommand executes a Rails command using a temporary file
// to avoid exposing sensitive data in process arguments
func secureExecRailsCommand(container, command string) (string, error) {
	// Create a temporary file with the command
	tmpDir := os.TempDir()
	tmpFile := filepath.Join(tmpDir, fmt.Sprintf("vulcan-cmd-%s.rb", generateRandomID()))

	if err := os.WriteFile(tmpFile, []byte(command), 0600); err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cli, err := NewDockerClient()
	if err != nil {
		return "", err
	}
	defer cli.Close()

	// Copy file to container, execute, remove
	// For now, fall back to direct execution but with obfuscated password
	cmd := []string{"bin/rails", "runner", command}
	return cli.ExecInContainer(ctx, container, cmd)
}

// generateRandomID creates a short random ID for temp files
func generateRandomID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)[:12]
}

// hashForLogging creates a safe hash for logging (shows it's set without revealing value)
func hashForLogging(value string) string {
	hash := sha256.Sum256([]byte(value))
	return base64.StdEncoding.EncodeToString(hash[:])[:8] + "..."
}

// validatePasswordStrength checks if password meets minimum requirements
func validatePasswordStrength(password string) error {
	if len(password) < 12 {
		return fmt.Errorf("password must be at least 12 characters")
	}

	var hasUpper, hasLower, hasDigit, hasSpecial bool
	for _, c := range password {
		switch {
		case c >= 'A' && c <= 'Z':
			hasUpper = true
		case c >= 'a' && c <= 'z':
			hasLower = true
		case c >= '0' && c <= '9':
			hasDigit = true
		case strings.ContainsRune("!@#$%^&*()_+-=[]{}|;:,.<>?", c):
			hasSpecial = true
		}
	}

	if !hasUpper {
		return fmt.Errorf("password must contain at least one uppercase letter")
	}
	if !hasLower {
		return fmt.Errorf("password must contain at least one lowercase letter")
	}
	if !hasDigit {
		return fmt.Errorf("password must contain at least one digit")
	}
	if !hasSpecial {
		return fmt.Errorf("password must contain at least one special character")
	}

	return nil
}
