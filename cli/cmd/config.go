package cmd

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage Vulcan configuration",
	Long: `View and manage Vulcan configuration securely.

Commands:
  vulcan config show          # View current config (secrets masked)
  vulcan config edit          # Edit .env interactively
  vulcan config rotate        # Rotate all secrets
  vulcan config validate      # Validate configuration`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current configuration",
	Long:  `Display current configuration with secrets masked for security.`,
	Run:   runConfigShow,
}

var configEditCmd = &cobra.Command{
	Use:   "edit",
	Short: "Edit configuration interactively",
	Long:  `Interactively edit configuration settings.`,
	Run:   runConfigEdit,
}

var configRotateCmd = &cobra.Command{
	Use:   "rotate",
	Short: "Rotate secrets",
	Long:  `Generate new secure secrets. This will require restarting services.`,
	Run:   runConfigRotate,
}

var configValidateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate configuration",
	Long:  `Check configuration for common issues and security problems.`,
	Run:   runConfigValidate,
}

var (
	showSecrets bool
)

func init() {
	rootCmd.AddCommand(configCmd)
	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configEditCmd)
	configCmd.AddCommand(configRotateCmd)
	configCmd.AddCommand(configValidateCmd)

	configShowCmd.Flags().BoolVar(&showSecrets, "show-secrets", false, "Show actual secret values (dangerous)")
}

// EnvVar represents a parsed environment variable
type EnvVar struct {
	Key       string
	Value     string
	IsSecret  bool
	IsComment bool
	Raw       string
}

// Secret key patterns to mask
var secretPatterns = []string{
	"PASSWORD",
	"SECRET",
	"TOKEN",
	"KEY",
	"CIPHER",
	"SALT",
	"PRIVATE",
	"CREDENTIAL",
}

func isSecret(key string) bool {
	keyUpper := strings.ToUpper(key)
	for _, pattern := range secretPatterns {
		if strings.Contains(keyUpper, pattern) {
			return true
		}
	}
	return false
}

func parseEnvFile(path string) ([]EnvVar, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var vars []EnvVar
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()

		// Handle empty lines and comments
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			vars = append(vars, EnvVar{
				Raw:       line,
				IsComment: true,
			})
			continue
		}

		// Parse KEY=VALUE
		if idx := strings.Index(line, "="); idx > 0 {
			key := strings.TrimSpace(line[:idx])
			value := strings.TrimSpace(line[idx+1:])
			vars = append(vars, EnvVar{
				Key:      key,
				Value:    value,
				IsSecret: isSecret(key),
				Raw:      line,
			})
		} else {
			vars = append(vars, EnvVar{
				Raw:       line,
				IsComment: true,
			})
		}
	}

	return vars, scanner.Err()
}

func writeEnvVars(path string, vars []EnvVar) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	for _, v := range vars {
		if v.IsComment {
			fmt.Fprintln(file, v.Raw)
		} else {
			fmt.Fprintf(file, "%s=%s\n", v.Key, v.Value)
		}
	}

	// Set secure permissions
	return os.Chmod(path, 0600)
}

func runConfigShow(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		printError("No .env file found. Run 'vulcan setup' first.")
		os.Exit(1)
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		os.Exit(1)
	}

	printTitle("Vulcan Configuration")
	fmt.Println()

	// Styles
	keyStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#3B82F6")).Bold(true)
	valueStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#10B981"))
	secretStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#EF4444"))
	commentStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#6B7280"))

	for _, v := range vars {
		if v.IsComment {
			if strings.HasPrefix(strings.TrimSpace(v.Raw), "#") && strings.Contains(v.Raw, "===") {
				// Section header
				fmt.Println()
				fmt.Println(commentStyle.Render(v.Raw))
			} else if strings.TrimSpace(v.Raw) != "" {
				fmt.Println(commentStyle.Render(v.Raw))
			}
			continue
		}

		if v.IsSecret && !showSecrets {
			// Mask the secret
			masked := "****" + v.Value[max(0, len(v.Value)-4):]
			fmt.Printf("  %s = %s\n", keyStyle.Render(v.Key), secretStyle.Render(masked))
		} else {
			fmt.Printf("  %s = %s\n", keyStyle.Render(v.Key), valueStyle.Render(v.Value))
		}
	}

	fmt.Println()
	if !showSecrets {
		printInfo("Secrets are masked. Use --show-secrets to reveal (dangerous)")
	} else {
		fmt.Println(errorStyle.Render("⚠ WARNING: Secrets are visible!"))
	}
}

func runConfigEdit(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		printError("No .env file found. Run 'vulcan setup' first.")
		os.Exit(1)
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		os.Exit(1)
	}

	printTitle("Edit Configuration")
	fmt.Println()

	// Group variables by category
	categories := map[string][]int{
		"Database":       {},
		"Authentication": {},
		"Application":    {},
		"Email":          {},
		"Other":          {},
	}

	for i, v := range vars {
		if v.IsComment {
			continue
		}
		switch {
		case strings.Contains(v.Key, "POSTGRES") || strings.Contains(v.Key, "DATABASE"):
			categories["Database"] = append(categories["Database"], i)
		case strings.Contains(v.Key, "AUTH") || strings.Contains(v.Key, "OIDC") ||
			strings.Contains(v.Key, "LDAP") || strings.Contains(v.Key, "LOGIN"):
			categories["Authentication"] = append(categories["Authentication"], i)
		case strings.Contains(v.Key, "SMTP") || strings.Contains(v.Key, "EMAIL"):
			categories["Email"] = append(categories["Email"], i)
		case strings.Contains(v.Key, "APP") || strings.Contains(v.Key, "URL") ||
			strings.Contains(v.Key, "WELCOME") || strings.Contains(v.Key, "CONTACT"):
			categories["Application"] = append(categories["Application"], i)
		default:
			categories["Other"] = append(categories["Other"], i)
		}
	}

	// Let user select category to edit
	var selectedCategory string
	categoryOptions := []huh.Option[string]{}
	for cat, indices := range categories {
		if len(indices) > 0 {
			categoryOptions = append(categoryOptions, huh.NewOption(
				fmt.Sprintf("%s (%d settings)", cat, len(indices)),
				cat,
			))
		}
	}

	if len(categoryOptions) == 0 {
		printError("No editable settings found")
		return
	}

	err = huh.NewSelect[string]().
		Title("Select category to edit").
		Options(categoryOptions...).
		Value(&selectedCategory).
		Run()

	if err != nil {
		return
	}

	// Let user select specific setting
	indices := categories[selectedCategory]
	var selectedIdx int
	settingOptions := []huh.Option[int]{}

	for _, idx := range indices {
		v := vars[idx]
		display := v.Key
		if v.IsSecret {
			display += " (secret)"
		}
		settingOptions = append(settingOptions, huh.NewOption(display, idx))
	}

	err = huh.NewSelect[int]().
		Title("Select setting to edit").
		Options(settingOptions...).
		Value(&selectedIdx).
		Run()

	if err != nil {
		return
	}

	v := vars[selectedIdx]
	fmt.Printf("\nCurrent value: ")
	if v.IsSecret {
		fmt.Println(errorStyle.Render("(hidden)"))
	} else {
		fmt.Println(infoStyle.Render(v.Value))
	}

	// Get new value
	var newValue string
	inputField := huh.NewInput().
		Title("Enter new value for " + v.Key).
		Value(&newValue)

	if v.IsSecret {
		inputField.EchoMode(huh.EchoModePassword)
	}

	err = inputField.Run()
	if err != nil {
		return
	}

	if newValue == "" {
		printInfo("No changes made")
		return
	}

	// Confirm change
	var confirm bool
	huh.NewConfirm().
		Title("Save changes?").
		Description(fmt.Sprintf("Set %s to new value", v.Key)).
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Changes cancelled")
		return
	}

	// Update and save
	vars[selectedIdx].Value = newValue
	if err := writeEnvVars(envPath, vars); err != nil {
		printError("Failed to save: " + err.Error())
		os.Exit(1)
	}

	printSuccess("Configuration updated")
	printInfo("Restart services for changes to take effect")
}

func runConfigRotate(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		printError("No .env file found. Run 'vulcan setup' first.")
		os.Exit(1)
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		os.Exit(1)
	}

	printTitle("Rotate Secrets")
	fmt.Println()

	// Find secrets that can be rotated
	rotatable := []string{
		"POSTGRES_PASSWORD",
		"SECRET_KEY_BASE",
		"CIPHER_PASSWORD",
		"CIPHER_SALT",
	}

	var toRotate []string
	rotatableOptions := []huh.Option[string]{}
	for _, key := range rotatable {
		for _, v := range vars {
			if v.Key == key {
				rotatableOptions = append(rotatableOptions, huh.NewOption(key, key))
				break
			}
		}
	}

	if len(rotatableOptions) == 0 {
		printInfo("No rotatable secrets found")
		return
	}

	err = huh.NewMultiSelect[string]().
		Title("Select secrets to rotate").
		Description("Warning: Rotating some secrets may require data migration").
		Options(rotatableOptions...).
		Value(&toRotate).
		Run()

	if err != nil || len(toRotate) == 0 {
		printInfo("No secrets selected")
		return
	}

	// Show warnings
	for _, key := range toRotate {
		switch key {
		case "POSTGRES_PASSWORD":
			fmt.Println(warningStyle.Render("⚠ POSTGRES_PASSWORD: You'll need to update the database user password"))
		case "SECRET_KEY_BASE":
			fmt.Println(warningStyle.Render("⚠ SECRET_KEY_BASE: All sessions will be invalidated"))
		case "CIPHER_PASSWORD", "CIPHER_SALT":
			fmt.Println(warningStyle.Render("⚠ CIPHER: Encrypted data will become unreadable"))
		}
	}
	fmt.Println()

	var confirm bool
	huh.NewConfirm().
		Title("Proceed with rotation?").
		Description("This action cannot be undone").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Rotation cancelled")
		return
	}

	// Backup current .env
	backupPath := envPath + ".backup"
	data, _ := os.ReadFile(envPath)
	os.WriteFile(backupPath, data, 0600)
	printSuccess("Backup saved to .env.backup")

	// Rotate selected secrets
	for i, v := range vars {
		for _, key := range toRotate {
			if v.Key == key {
				var newValue string
				switch key {
				case "POSTGRES_PASSWORD":
					newValue = generateSecureToken(33)
				case "SECRET_KEY_BASE":
					newValue = generateSecureToken(64)
				case "CIPHER_PASSWORD":
					newValue = generateSecureToken(64)
				case "CIPHER_SALT":
					newValue = generateSecureToken(32)
				}
				vars[i].Value = newValue
				printSuccess("Rotated " + key)
			}
		}
	}

	if err := writeEnvVars(envPath, vars); err != nil {
		printError("Failed to save: " + err.Error())
		os.Exit(1)
	}

	fmt.Println()
	printSuccess("Secrets rotated successfully")
	printInfo("Restart services for changes to take effect")

	if containsString(toRotate, "POSTGRES_PASSWORD") {
		fmt.Println()
		printInfo("To update PostgreSQL password, run:")
		fmt.Println("  docker compose exec db psql -U postgres -c \"ALTER USER postgres PASSWORD 'new_password';\"")
	}
}

func runConfigValidate(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		printError("No .env file found. Run 'vulcan setup' first.")
		os.Exit(1)
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		os.Exit(1)
	}

	printTitle("Configuration Validation")
	fmt.Println()

	issues := []string{}
	warnings := []string{}

	// Create map for easy lookup
	envMap := make(map[string]string)
	for _, v := range vars {
		if !v.IsComment {
			envMap[v.Key] = v.Value
		}
	}

	// Check required settings
	required := []string{
		"SECRET_KEY_BASE",
		"CIPHER_PASSWORD",
		"CIPHER_SALT",
	}

	for _, key := range required {
		if val, ok := envMap[key]; !ok || val == "" {
			issues = append(issues, fmt.Sprintf("Missing required: %s", key))
		}
	}

	// Check for insecure defaults
	if val, ok := envMap["SECRET_KEY_BASE"]; ok {
		if strings.Contains(val, "development") || strings.Contains(val, "change_me") {
			issues = append(issues, "SECRET_KEY_BASE contains insecure default value")
		}
		if len(val) < 64 {
			warnings = append(warnings, "SECRET_KEY_BASE should be at least 64 characters")
		}
	}

	if val, ok := envMap["POSTGRES_PASSWORD"]; ok {
		if val == "postgres" || val == "password" || val == "changeme" {
			issues = append(issues, "POSTGRES_PASSWORD uses insecure default")
		}
	}

	// Check URL format
	if val, ok := envMap["VULCAN_APP_URL"]; ok && val != "" {
		if !strings.HasPrefix(val, "http://") && !strings.HasPrefix(val, "https://") {
			issues = append(issues, "VULCAN_APP_URL must start with http:// or https://")
		}
		if strings.HasPrefix(val, "http://") && envMap["RAILS_ENV"] == "production" {
			warnings = append(warnings, "VULCAN_APP_URL uses HTTP in production (should be HTTPS)")
		}
	}

	// Check OIDC configuration
	if envMap["VULCAN_ENABLE_OIDC"] == "true" {
		oidcRequired := []string{"VULCAN_OIDC_ISSUER_URL", "VULCAN_OIDC_CLIENT_ID", "VULCAN_OIDC_CLIENT_SECRET"}
		for _, key := range oidcRequired {
			if val, ok := envMap[key]; !ok || val == "" {
				issues = append(issues, fmt.Sprintf("OIDC enabled but %s is missing", key))
			}
		}
	}

	// Check LDAP configuration
	if envMap["VULCAN_ENABLE_LDAP"] == "true" {
		ldapRequired := []string{"VULCAN_LDAP_HOST", "VULCAN_LDAP_BASE"}
		for _, key := range ldapRequired {
			if val, ok := envMap[key]; !ok || val == "" {
				issues = append(issues, fmt.Sprintf("LDAP enabled but %s is missing", key))
			}
		}
	}

	// Check email format
	if val, ok := envMap["VULCAN_CONTACT_EMAIL"]; ok && val != "" {
		emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
		if !emailRegex.MatchString(val) {
			warnings = append(warnings, "VULCAN_CONTACT_EMAIL doesn't look like a valid email")
		}
	}

	// Check file permissions
	info, _ := os.Stat(envPath)
	mode := info.Mode().Perm()
	if mode&0077 != 0 {
		issues = append(issues, fmt.Sprintf(".env has insecure permissions (%o). Should be 600", mode))
	}

	// Print results
	if len(issues) == 0 && len(warnings) == 0 {
		printSuccess("Configuration is valid!")
		return
	}

	if len(issues) > 0 {
		fmt.Println(errorStyle.Render("Issues:"))
		for _, issue := range issues {
			fmt.Printf("  %s %s\n", errorStyle.Render("✗"), issue)
		}
		fmt.Println()
	}

	if len(warnings) > 0 {
		fmt.Println(warningStyle.Render("Warnings:"))
		for _, warning := range warnings {
			fmt.Printf("  %s %s\n", warningStyle.Render("⚠"), warning)
		}
		fmt.Println()
	}

	if len(issues) > 0 {
		os.Exit(1)
	}
}

