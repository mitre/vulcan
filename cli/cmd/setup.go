package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

// SetupConfig holds all configuration gathered from the wizard
type SetupConfig struct {
	Environment string // "development" or "production"

	// Ports
	WebPort      string
	DatabasePort string

	// Database
	PostgresPassword string
	DatabaseURL      string

	// Rails secrets
	SecretKeyBase  string
	CipherPassword string
	CipherSalt     string

	// Authentication
	AuthMethod      string // "local", "oidc", "ldap"
	EnableLocalAuth bool

	// OIDC settings
	OIDCProviderTitle string
	OIDCIssuerURL     string
	OIDCClientID      string
	OIDCClientSecret  string
	OIDCRedirectURI   string

	// LDAP settings
	LDAPHost     string
	LDAPPort     string
	LDAPBase     string
	LDAPBindDN   string
	LDAPPassword string

	// Application settings
	AppURL       string
	ContactEmail string
	WelcomeText  string

	// SMTP settings
	EnableSMTP   bool
	SMTPAddress  string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string
}

var (
	setupDryRun bool
)

var setupCmd = &cobra.Command{
	Use:   "setup [dev|production]",
	Short: "Interactive setup wizard",
	Long: `Run the interactive setup wizard to configure Vulcan.

For development:
  vulcan setup dev         # Quick setup with sensible defaults

For production:
  vulcan setup production  # Full wizard with secure secrets

Options:
  --dry-run                Show what would be done without executing`,
	Args: cobra.MaximumNArgs(1),
	Run:  runSetup,
}

func init() {
	rootCmd.AddCommand(setupCmd)
	setupCmd.Flags().BoolVar(&setupDryRun, "dry-run", false, "Show what would be done without executing")
}

func runSetup(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	// Display banner
	banner := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#7C3AED")).
		Render(`
 ╦  ╦┬ ┬┬  ┌─┐┌─┐┌┐┌
 ╚╗╔╝│ ││  │  ├─┤│││
  ╚╝ └─┘┴─┘└─┘┴ ┴┘└┘`)

	fmt.Println(banner)
	fmt.Println(subtitleStyle.Render("  Setup Wizard v2.3.0\n"))

	config := &SetupConfig{}

	// Determine environment
	if len(args) > 0 {
		switch strings.ToLower(args[0]) {
		case "dev", "development":
			config.Environment = "development"
		case "prod", "production":
			config.Environment = "production"
		default:
			printError("Invalid environment. Use 'dev' or 'production'")
			os.Exit(1)
		}
	} else {
		// Ask user to select environment
		err := huh.NewSelect[string]().
			Title("Select environment").
			Description("Choose your deployment target").
			Options(
				huh.NewOption("Development (local machine)", "development"),
				huh.NewOption("Production (Docker deployment)", "production"),
			).
			Value(&config.Environment).
			Run()
		if err != nil {
			printError("Setup cancelled")
			os.Exit(1)
		}
	}

	if config.Environment == "development" {
		runDevSetup(config, projectRoot)
	} else {
		runProductionSetup(config, projectRoot)
	}
}

func runDevSetup(config *SetupConfig, projectRoot string) {
	printTitle("\n Development Setup")
	if setupDryRun {
		printInfo("[DRY RUN] Showing what would be done...\n")
	} else {
		printInfo("Setting up Vulcan for local development...\n")
	}

	// Set development defaults
	config.WebPort = "3000"
	config.DatabasePort = "5432"
	config.PostgresPassword = "postgres"
	config.SecretKeyBase = "development_secret_key_base_not_for_production_use"
	config.CipherPassword = "development_cipher_password_not_for_production_use"
	config.CipherSalt = "development_cipher_salt_not_for_production_use"
	config.EnableLocalAuth = true
	config.ContactEmail = "admin@example.com"
	config.WelcomeText = "Welcome to Vulcan Development"

	// Check default ports and ask for configuration
	webPortInUse := isPortInUse(config.WebPort)
	dbPortInUse := isPortInUse(config.DatabasePort)

	if webPortInUse || dbPortInUse {
		fmt.Println()
		printInfo("Port Configuration")
		fmt.Println()

		if webPortInUse {
			altPort := suggestAlternativePort(3000)
			printError(fmt.Sprintf("Port %s is in use (Rails server)", config.WebPort))
			printInfo(fmt.Sprintf("Suggested alternative: %s", altPort))

			huh.NewInput().
				Title("Web server port").
				Value(&config.WebPort).
				Placeholder(altPort).
				Run()

			if config.WebPort == "" {
				config.WebPort = altPort
			}
		}

		if dbPortInUse {
			altPort := suggestAlternativePort(5432)
			printError(fmt.Sprintf("Port %s is in use (PostgreSQL)", config.DatabasePort))
			printInfo(fmt.Sprintf("Suggested alternative: %s", altPort))

			huh.NewInput().
				Title("Database port").
				Value(&config.DatabasePort).
				Placeholder(altPort).
				Run()

			if config.DatabasePort == "" {
				config.DatabasePort = altPort
			}
		}
		fmt.Println()
	}

	config.AppURL = fmt.Sprintf("http://localhost:%s", config.WebPort)

	// Ask about OIDC (optional for dev)
	var configureOIDC bool
	huh.NewConfirm().
		Title("Configure OIDC authentication?").
		Description("Set up SSO with Okta, Auth0, Azure AD, etc.").
		Value(&configureOIDC).
		Run()

	if configureOIDC {
		config.AuthMethod = "oidc"

		oidcForm := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("OIDC Provider Name").
					Description("Display name (e.g., 'Corporate SSO')").
					Placeholder("Okta").
					Value(&config.OIDCProviderTitle),

				huh.NewInput().
					Title("OIDC Issuer URL").
					Description("Your identity provider's base URL").
					Placeholder("https://your-domain.okta.com").
					Value(&config.OIDCIssuerURL),

				huh.NewInput().
					Title("Client ID").
					Placeholder("your-client-id").
					Value(&config.OIDCClientID),

				huh.NewInput().
					Title("Client Secret").
					EchoMode(huh.EchoModePassword).
					Placeholder("your-client-secret").
					Value(&config.OIDCClientSecret),
			).Title("OIDC Configuration"),
		)

		if err := oidcForm.Run(); err != nil {
			printInfo("Skipping OIDC configuration")
			config.AuthMethod = ""
		} else {
			config.OIDCRedirectURI = fmt.Sprintf("http://localhost:%s/users/auth/oidc/callback", config.WebPort)
		}
	}

	// Check prerequisites
	fmt.Println()
	printInfo("Checking prerequisites...")
	fmt.Println()

	checks := []struct {
		name    string
		command string
		args    []string
	}{
		{"Docker", "docker", []string{"info"}},
		{"Ruby", "ruby", []string{"--version"}},
		{"pnpm", "pnpm", []string{"--version"}},
	}

	for _, check := range checks {
		cmd := exec.Command(check.command, check.args...)
		cmd.Stdout = nil
		cmd.Stderr = nil
		if err := cmd.Run(); err != nil {
			printError(check.name + " not found. Please install it first.")
			os.Exit(1)
		}
		printSuccess(check.name + " found")
	}
	fmt.Println()

	// Create .env file
	envPath := filepath.Join(projectRoot, ".env")
	if setupDryRun {
		printInfo("[DRY RUN] Would create .env file")
		fmt.Println()
		fmt.Println("  Environment variables:")
		fmt.Printf("    PORT=%s\n", config.WebPort)
		fmt.Printf("    DATABASE_PORT=%s\n", config.DatabasePort)
		fmt.Println("    POSTGRES_PASSWORD=postgres")
		fmt.Println("    SECRET_KEY_BASE=development_secret_...")
		fmt.Println("    CIPHER_PASSWORD=development_cipher_...")
		fmt.Println("    VULCAN_ENABLE_LOCAL_LOGIN=true")
		fmt.Printf("    VULCAN_APP_URL=%s\n", config.AppURL)
		if config.AuthMethod == "oidc" {
			fmt.Println("    VULCAN_ENABLE_OIDC=true")
			fmt.Printf("    VULCAN_OIDC_ISSUER_URL=%s\n", config.OIDCIssuerURL)
		}
		fmt.Println()
	} else {
		if _, err := os.Stat(envPath); err == nil {
			var overwrite bool
			huh.NewConfirm().
				Title(".env file already exists").
				Description("Do you want to overwrite it?").
				Value(&overwrite).
				Run()
			if !overwrite {
				printInfo("Keeping existing .env file")
			} else {
				writeEnvFile(config, envPath)
			}
		} else {
			writeEnvFile(config, envPath)
		}
	}

	// Run setup steps
	steps := []struct {
		title   string
		command string
		args    []string
	}{
		{"Starting PostgreSQL with Docker...", "docker", []string{"compose", "-f", "docker-compose.dev.yml", "up", "-d"}},
		{"Installing Ruby dependencies...", "bundle", []string{"install"}},
		{"Installing JavaScript dependencies...", "pnpm", []string{"install"}},
		{"Building frontend assets...", "pnpm", []string{"build"}},
		{"Preparing database...", "bundle", []string{"exec", "rails", "db:prepare"}},
	}

	if setupDryRun {
		printInfo("[DRY RUN] Would execute:")
		fmt.Println()
		for i, step := range steps {
			title := strings.TrimSuffix(step.title, "...")
			fmt.Printf("  %d. %s\n", i+1, title)
			fmt.Printf("     $ %s %s\n", step.command, strings.Join(step.args, " "))
		}
		fmt.Println()
	} else {
		for _, step := range steps {
			var stepErr error
			spinner.New().
				Title(step.title).
				Action(func() {
					cmd := exec.Command(step.command, step.args...)
					cmd.Dir = projectRoot
					stepErr = cmd.Run()
				}).
				Run()
			if stepErr != nil {
				printError("Failed: " + step.title)
				printError(stepErr.Error())
				os.Exit(1)
			}
			printSuccess(strings.TrimSuffix(step.title, "..."))
		}
	}

	// Success!
	fmt.Println()
	if setupDryRun {
		successBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#3B82F6")).
			Padding(1, 2).
			Render(
				infoStyle.Render("[DRY RUN] Setup Preview Complete") + "\n\n" +
					"To run setup for real:\n" +
					infoStyle.Render("  vulcan setup dev") + "\n\n" +
					"After setup, start with:\n" +
					infoStyle.Render("  vulcan start"))
		fmt.Println(successBox)
		return
	}

	successBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#10B981")).
		Padding(1, 2).
		Render(
			successStyle.Render("Setup Complete!") + "\n\n" +
				"Start Vulcan:\n" +
				infoStyle.Render("  vulcan start") + " or " + infoStyle.Render("foreman start -f Procfile.dev") + "\n\n" +
				"Access Vulcan:\n" +
				infoStyle.Render("  http://localhost:3000") + "\n\n" +
				"Default login:\n" +
				"  Email:    " + infoStyle.Render("admin@example.com") + "\n" +
				"  Password: " + infoStyle.Render("1234567ab!"))
	fmt.Println(successBox)

	// Ask if user wants to start now
	var startNow bool
	huh.NewConfirm().
		Title("Start Vulcan now?").
		Value(&startNow).
		Run()

	if startNow {
		fmt.Println()
		printInfo("Starting Vulcan...")
		cmd := exec.Command("foreman", "start", "-f", "Procfile.dev")
		cmd.Dir = projectRoot
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		cmd.Run()
	}
}

func runProductionSetup(config *SetupConfig, projectRoot string) {
	printTitle("\n Production Setup")
	if setupDryRun {
		printInfo("[DRY RUN] Showing production setup wizard...\n")
	} else {
		printInfo("Configuring Vulcan for production deployment...\n")
	}

	// Set default ports
	config.WebPort = "3000"
	config.DatabasePort = "5432"

	// Generate secure secrets
	config.PostgresPassword = generateSecureToken(33)
	config.SecretKeyBase = generateSecureToken(64)
	config.CipherPassword = generateSecureToken(64)
	config.CipherSalt = generateSecureToken(32)

	// Port configuration form
	portForm := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Web server port").
				Description("Port for the Rails application").
				Placeholder("3000").
				Value(&config.WebPort),

			huh.NewInput().
				Title("Database port").
				Description("Port for PostgreSQL").
				Placeholder("5432").
				Value(&config.DatabasePort),
		).Title("Port Configuration"),
	)

	if err := portForm.Run(); err != nil {
		printError("Setup cancelled")
		os.Exit(1)
	}

	// Set defaults if empty
	if config.WebPort == "" {
		config.WebPort = "3000"
	}
	if config.DatabasePort == "" {
		config.DatabasePort = "5432"
	}

	// Authentication form
	authForm := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Primary authentication method").
				Description("How will users authenticate?").
				Options(
					huh.NewOption("OIDC/OAuth2 (Okta, Auth0, Azure AD, etc.)", "oidc"),
					huh.NewOption("LDAP/Active Directory", "ldap"),
					huh.NewOption("Local accounts only", "local"),
				).
				Value(&config.AuthMethod),

			huh.NewConfirm().
				Title("Also enable local login?").
				Description("Allow username/password login alongside SSO").
				Value(&config.EnableLocalAuth),
		),
	)

	if err := authForm.Run(); err != nil {
		printError("Setup cancelled")
		os.Exit(1)
	}

	// OIDC configuration
	if config.AuthMethod == "oidc" {
		oidcForm := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("OIDC Provider Name").
					Description("Display name (e.g., 'Corporate SSO')").
					Placeholder("Your Organization").
					Value(&config.OIDCProviderTitle),

				huh.NewInput().
					Title("OIDC Issuer URL").
					Description("Your identity provider's base URL").
					Placeholder("https://your-domain.okta.com").
					Value(&config.OIDCIssuerURL),

				huh.NewInput().
					Title("Client ID").
					Placeholder("your-client-id").
					Value(&config.OIDCClientID),

				huh.NewInput().
					Title("Client Secret").
					Placeholder("your-client-secret").
					EchoMode(huh.EchoModePassword).
					Value(&config.OIDCClientSecret),
			),
		)

		if err := oidcForm.Run(); err != nil {
			printError("Setup cancelled")
			os.Exit(1)
		}
	}

	// LDAP configuration
	if config.AuthMethod == "ldap" {
		ldapForm := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("LDAP Host").
					Placeholder("ldap.example.com").
					Value(&config.LDAPHost),

				huh.NewInput().
					Title("LDAP Port").
					Placeholder("636").
					Value(&config.LDAPPort),

				huh.NewInput().
					Title("LDAP Base DN").
					Placeholder("dc=example,dc=com").
					Value(&config.LDAPBase),

				huh.NewInput().
					Title("Bind DN").
					Placeholder("cn=admin,dc=example,dc=com").
					Value(&config.LDAPBindDN),

				huh.NewInput().
					Title("Bind Password").
					EchoMode(huh.EchoModePassword).
					Value(&config.LDAPPassword),
			),
		)

		if err := ldapForm.Run(); err != nil {
			printError("Setup cancelled")
			os.Exit(1)
		}
	}

	// Application settings
	appForm := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Application URL").
				Description("Public URL where Vulcan will be accessible").
				Placeholder("https://vulcan.your-org.com").
				Value(&config.AppURL),

			huh.NewInput().
				Title("Contact Email").
				Description("Admin contact email for the application").
				Placeholder("vulcan-admin@your-org.com").
				Value(&config.ContactEmail),

			huh.NewInput().
				Title("Welcome Message").
				Description("Displayed on the login page").
				Placeholder("Welcome to Vulcan").
				Value(&config.WelcomeText),
		),
	)

	if err := appForm.Run(); err != nil {
		printError("Setup cancelled")
		os.Exit(1)
	}

	// Set redirect URI based on app URL
	config.OIDCRedirectURI = config.AppURL + "/users/auth/oidc/callback"

	// SMTP configuration (optional)
	huh.NewConfirm().
		Title("Configure email (SMTP)?").
		Description("Required for password resets and notifications").
		Value(&config.EnableSMTP).
		Run()

	if config.EnableSMTP {
		smtpForm := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("SMTP Server").
					Placeholder("smtp.gmail.com").
					Value(&config.SMTPAddress),

				huh.NewInput().
					Title("SMTP Port").
					Placeholder("587").
					Value(&config.SMTPPort),

				huh.NewInput().
					Title("SMTP Username").
					Placeholder("notifications@example.com").
					Value(&config.SMTPUsername),

				huh.NewInput().
					Title("SMTP Password").
					EchoMode(huh.EchoModePassword).
					Value(&config.SMTPPassword),
			),
		)

		if err := smtpForm.Run(); err != nil {
			printError("Setup cancelled")
			os.Exit(1)
		}
	}

	// Write .env file
	envPath := filepath.Join(projectRoot, ".env")

	if setupDryRun {
		printInfo("[DRY RUN] Would create .env file at: " + envPath)
		printInfo("[DRY RUN] Configuration summary:")
		fmt.Println()
		printInfo("  Auth Method: " + config.AuthMethod)
		printInfo("  Local Login: " + fmt.Sprintf("%v", config.EnableLocalAuth))
		if config.AuthMethod == "oidc" {
			printInfo("  OIDC Provider: " + config.OIDCProviderTitle)
			printInfo("  OIDC Issuer: " + config.OIDCIssuerURL)
		} else if config.AuthMethod == "ldap" {
			printInfo("  LDAP Host: " + config.LDAPHost)
		}
		printInfo("  App URL: " + config.AppURL)
		printInfo("  Contact Email: " + config.ContactEmail)
		printInfo("  SMTP Enabled: " + fmt.Sprintf("%v", config.EnableSMTP))
		fmt.Println()

		successBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#3B82F6")).
			Padding(1, 2).
			Render(
				infoStyle.Render("[DRY RUN] Production Setup Preview Complete") + "\n\n" +
					"To run setup for real:\n" +
					infoStyle.Render("  vulcan setup production") + "\n\n" +
					"The wizard will generate secure secrets\n" +
					"and create your .env configuration file.")
		fmt.Println(successBox)
		return
	}

	writeEnvFile(config, envPath)

	// Success message
	fmt.Println()
	successBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#10B981")).
		Padding(1, 2).
		Render(
			successStyle.Render("Production Configuration Complete!") + "\n\n" +
				"Configuration saved to:\n" +
				infoStyle.Render("  .env") + "\n\n" +
				"Next steps:\n" +
				"  1. Review .env and adjust as needed\n" +
				"  2. Start with: " + infoStyle.Render("docker compose up -d") + "\n" +
				"  3. Initialize DB: " + infoStyle.Render("docker compose exec web bin/rails db:prepare") + "\n" +
				"  4. Access at: " + infoStyle.Render(config.AppURL))
	fmt.Println(successBox)
}

func writeEnvFile(config *SetupConfig, path string) {
	tmpl := `# Vulcan Environment Configuration
# Generated by vulcan setup wizard
# Environment: {{ .Environment }}

# =============================================================================
# PORTS (No hardcoded ports - all configurable via env vars)
# =============================================================================
PORT={{ .WebPort }}
DATABASE_PORT={{ .DatabasePort }}

# =============================================================================
# DATABASE
# =============================================================================
POSTGRES_PASSWORD={{ .PostgresPassword }}
{{- if eq .Environment "development" }}
# DATABASE_URL is handled by database.yml in development
{{- else }}
DATABASE_URL=postgres://postgres:{{ .PostgresPassword }}@db:{{ .DatabasePort }}/vulcan_postgres_production
{{- end }}

# =============================================================================
# RAILS SECRETS
# =============================================================================
SECRET_KEY_BASE={{ .SecretKeyBase }}
CIPHER_PASSWORD={{ .CipherPassword }}
CIPHER_SALT={{ .CipherSalt }}

# =============================================================================
# AUTHENTICATION
# =============================================================================
{{- if or (eq .AuthMethod "oidc") .EnableLocalAuth }}
VULCAN_ENABLE_LOCAL_LOGIN={{ .EnableLocalAuth }}
{{- else if eq .AuthMethod "local" }}
VULCAN_ENABLE_LOCAL_LOGIN=true
{{- else }}
VULCAN_ENABLE_LOCAL_LOGIN={{ .EnableLocalAuth }}
{{- end }}
VULCAN_ENABLE_USER_REGISTRATION={{ if eq .Environment "development" }}true{{ else }}false{{ end }}
VULCAN_SESSION_TIMEOUT=60

{{- if eq .AuthMethod "oidc" }}

# OIDC Configuration
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_PROVIDER_TITLE={{ .OIDCProviderTitle }}
VULCAN_OIDC_ISSUER_URL={{ .OIDCIssuerURL }}
VULCAN_OIDC_CLIENT_ID={{ .OIDCClientID }}
VULCAN_OIDC_CLIENT_SECRET={{ .OIDCClientSecret }}
VULCAN_OIDC_REDIRECT_URI={{ .OIDCRedirectURI }}
VULCAN_OIDC_DISCOVERY=true
{{- else }}
VULCAN_ENABLE_OIDC=false
{{- end }}

{{- if eq .AuthMethod "ldap" }}

# LDAP Configuration
VULCAN_ENABLE_LDAP=true
VULCAN_LDAP_HOST={{ .LDAPHost }}
VULCAN_LDAP_PORT={{ .LDAPPort }}
VULCAN_LDAP_BASE={{ .LDAPBase }}
VULCAN_LDAP_BIND_DN={{ .LDAPBindDN }}
VULCAN_LDAP_ADMIN_PASS={{ .LDAPPassword }}
{{- else }}
VULCAN_ENABLE_LDAP=false
{{- end }}

# =============================================================================
# APPLICATION SETTINGS
# =============================================================================
VULCAN_APP_URL={{ .AppURL }}
VULCAN_CONTACT_EMAIL={{ .ContactEmail }}
VULCAN_WELCOME_TEXT={{ .WelcomeText }}
VULCAN_PROJECT_CREATE_PERMISSION_ENABLED={{ if eq .Environment "production" }}true{{ else }}false{{ end }}

# =============================================================================
# EMAIL/SMTP
# =============================================================================
VULCAN_ENABLE_SMTP={{ .EnableSMTP }}
{{- if .EnableSMTP }}
VULCAN_SMTP_ADDRESS={{ .SMTPAddress }}
VULCAN_SMTP_PORT={{ .SMTPPort }}
VULCAN_SMTP_SERVER_USERNAME={{ .SMTPUsername }}
VULCAN_SMTP_SERVER_PASSWORD={{ .SMTPPassword }}
{{- end }}

# =============================================================================
# PRODUCTION SETTINGS
# =============================================================================
{{- if eq .Environment "production" }}
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
FORCE_SSL=true
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
{{- end }}

# =============================================================================
# NOTES
# =============================================================================
# Default admin login (after seeding): admin@example.com / 1234567ab!
# To seed the database: bundle exec rails db:seed
`

	t, err := template.New("env").Parse(tmpl)
	if err != nil {
		printError("Failed to parse template: " + err.Error())
		os.Exit(1)
	}

	f, err := os.Create(path)
	if err != nil {
		printError("Failed to create .env file: " + err.Error())
		os.Exit(1)
	}
	defer f.Close()

	if err := t.Execute(f, config); err != nil {
		printError("Failed to write .env file: " + err.Error())
		os.Exit(1)
	}

	// Set secure permissions
	os.Chmod(path, 0600)
	printSuccess("Created .env file")
}

