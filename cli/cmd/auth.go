package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var authCmd = &cobra.Command{
	Use:   "auth",
	Short: "Configure authentication providers",
	Long: `Configure authentication providers for Vulcan.

Commands:
  vulcan auth status           # Show current auth configuration
  vulcan auth setup-oidc       # Configure OIDC (Okta, Azure AD, Auth0, etc.)
  vulcan auth setup-ldap       # Configure LDAP/Active Directory
  vulcan auth test             # Test authentication configuration
  vulcan auth disable [provider]  # Disable an auth provider`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

var authStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show authentication configuration status",
	Run:   runAuthStatus,
}

var authSetupOIDCCmd = &cobra.Command{
	Use:   "setup-oidc",
	Short: "Configure OIDC authentication",
	Long: `Configure OIDC/OAuth2 authentication with your identity provider.

Supported providers:
  - Okta
  - Azure AD / Entra ID
  - Auth0
  - Keycloak
  - Google Workspace
  - Any OIDC-compliant provider`,
	Run: runAuthSetupOIDC,
}

var authSetupLDAPCmd = &cobra.Command{
	Use:   "setup-ldap",
	Short: "Configure LDAP/Active Directory authentication",
	Run:   runAuthSetupLDAP,
}

var authTestCmd = &cobra.Command{
	Use:   "test",
	Short: "Test authentication configuration",
	Run:   runAuthTest,
}

var authDisableCmd = &cobra.Command{
	Use:   "disable [oidc|ldap]",
	Short: "Disable an authentication provider",
	Args:  cobra.ExactArgs(1),
	Run:   runAuthDisable,
}

func init() {
	rootCmd.AddCommand(authCmd)
	authCmd.AddCommand(authStatusCmd)
	authCmd.AddCommand(authSetupOIDCCmd)
	authCmd.AddCommand(authSetupLDAPCmd)
	authCmd.AddCommand(authTestCmd)
	authCmd.AddCommand(authDisableCmd)
}

func runAuthStatus(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	printTitle("Authentication Status")
	fmt.Println()

	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		printError("No .env file found. Run 'vulcan setup' first.")
		return
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		return
	}

	envMap := make(map[string]string)
	for _, v := range vars {
		if !v.IsComment {
			envMap[v.Key] = v.Value
		}
	}

	// Check local auth
	localEnabled := envMap["VULCAN_ENABLE_LOCAL_LOGIN"] == "true"
	registrationEnabled := envMap["VULCAN_ENABLE_USER_REGISTRATION"] == "true"

	fmt.Println(subtitleStyle.Render("Local Authentication"))
	if localEnabled {
		fmt.Printf("  %s Local login enabled\n", successStyle.Render("●"))
	} else {
		fmt.Printf("  %s Local login disabled\n", infoStyle.Render("○"))
	}
	if registrationEnabled {
		fmt.Printf("  %s User registration enabled\n", successStyle.Render("●"))
	} else {
		fmt.Printf("  %s User registration disabled\n", infoStyle.Render("○"))
	}
	fmt.Println()

	// Check OIDC
	fmt.Println(subtitleStyle.Render("OIDC / OAuth2"))
	if envMap["VULCAN_ENABLE_OIDC"] == "true" {
		fmt.Printf("  %s OIDC enabled\n", successStyle.Render("●"))
		if title := envMap["VULCAN_OIDC_PROVIDER_TITLE"]; title != "" {
			fmt.Printf("  %s Provider: %s\n", infoStyle.Render("→"), title)
		}
		if issuer := envMap["VULCAN_OIDC_ISSUER_URL"]; issuer != "" {
			fmt.Printf("  %s Issuer: %s\n", infoStyle.Render("→"), issuer)
		}
		if clientID := envMap["VULCAN_OIDC_CLIENT_ID"]; clientID != "" {
			fmt.Printf("  %s Client ID: %s...%s\n", infoStyle.Render("→"),
				clientID[:min(8, len(clientID))],
				clientID[max(0, len(clientID)-4):])
		}
	} else {
		fmt.Printf("  %s OIDC not configured\n", infoStyle.Render("○"))
		fmt.Printf("    %s Run 'vulcan auth setup-oidc' to configure\n", infoStyle.Render("→"))
	}
	fmt.Println()

	// Check LDAP
	fmt.Println(subtitleStyle.Render("LDAP / Active Directory"))
	if envMap["VULCAN_ENABLE_LDAP"] == "true" {
		fmt.Printf("  %s LDAP enabled\n", successStyle.Render("●"))
		if host := envMap["VULCAN_LDAP_HOST"]; host != "" {
			port := envMap["VULCAN_LDAP_PORT"]
			if port == "" {
				port = "389"
			}
			fmt.Printf("  %s Server: %s:%s\n", infoStyle.Render("→"), host, port)
		}
		if base := envMap["VULCAN_LDAP_BASE"]; base != "" {
			fmt.Printf("  %s Base DN: %s\n", infoStyle.Render("→"), base)
		}
	} else {
		fmt.Printf("  %s LDAP not configured\n", infoStyle.Render("○"))
		fmt.Printf("    %s Run 'vulcan auth setup-ldap' to configure\n", infoStyle.Render("→"))
	}
}

func runAuthSetupOIDC(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	printTitle("OIDC Configuration")
	fmt.Println()

	// Provider presets
	type ProviderPreset struct {
		Name        string
		Description string
		IssuerHint  string
	}

	presets := []ProviderPreset{
		{"Okta", "Okta Workforce Identity", "https://your-domain.okta.com"},
		{"Azure AD", "Microsoft Entra ID / Azure Active Directory", "https://login.microsoftonline.com/{tenant-id}/v2.0"},
		{"Auth0", "Auth0 by Okta", "https://your-tenant.auth0.com"},
		{"Keycloak", "Red Hat Keycloak / SSO", "https://keycloak.example.com/realms/your-realm"},
		{"Google", "Google Workspace", "https://accounts.google.com"},
		{"Custom", "Any OIDC-compliant provider", "https://your-idp.example.com"},
	}

	var selectedProvider string
	options := make([]huh.Option[string], len(presets))
	for i, p := range presets {
		options[i] = huh.NewOption(fmt.Sprintf("%s - %s", p.Name, p.Description), p.Name)
	}

	err := huh.NewSelect[string]().
		Title("Select your identity provider").
		Options(options...).
		Value(&selectedProvider).
		Run()

	if err != nil {
		return
	}

	// Find preset
	var preset ProviderPreset
	for _, p := range presets {
		if p.Name == selectedProvider {
			preset = p
			break
		}
	}

	// Show provider-specific instructions
	fmt.Println()
	instructionBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#3B82F6")).
		Padding(1, 2)

	switch selectedProvider {
	case "Okta":
		fmt.Println(instructionBox.Render(
			infoStyle.Render("Okta Setup Instructions") + "\n\n" +
				"1. Log into Okta Admin Console\n" +
				"2. Applications → Create App Integration\n" +
				"3. Select 'OIDC - OpenID Connect' and 'Web Application'\n" +
				"4. Set Sign-in redirect URI:\n" +
				"   " + successStyle.Render("{your-vulcan-url}/users/auth/oidc/callback") + "\n" +
				"5. Copy Client ID and Client Secret"))
	case "Azure AD":
		fmt.Println(instructionBox.Render(
			infoStyle.Render("Azure AD / Entra ID Setup") + "\n\n" +
				"1. Go to Azure Portal → Microsoft Entra ID\n" +
				"2. App registrations → New registration\n" +
				"3. Set Redirect URI (Web):\n" +
				"   " + successStyle.Render("{your-vulcan-url}/users/auth/oidc/callback") + "\n" +
				"4. Certificates & secrets → New client secret\n" +
				"5. Copy Application (client) ID and secret\n" +
				"6. Note your Tenant ID for the issuer URL"))
	case "Auth0":
		fmt.Println(instructionBox.Render(
			infoStyle.Render("Auth0 Setup Instructions") + "\n\n" +
				"1. Log into Auth0 Dashboard\n" +
				"2. Applications → Create Application → Regular Web App\n" +
				"3. Settings → Allowed Callback URLs:\n" +
				"   " + successStyle.Render("{your-vulcan-url}/users/auth/oidc/callback") + "\n" +
				"4. Copy Domain, Client ID, and Client Secret"))
	case "Keycloak":
		fmt.Println(instructionBox.Render(
			infoStyle.Render("Keycloak Setup Instructions") + "\n\n" +
				"1. Log into Keycloak Admin Console\n" +
				"2. Select your realm (or create one)\n" +
				"3. Clients → Create client\n" +
				"4. Set Valid redirect URIs:\n" +
				"   " + successStyle.Render("{your-vulcan-url}/users/auth/oidc/callback") + "\n" +
				"5. Credentials tab → Copy Client Secret"))
	case "Google":
		fmt.Println(instructionBox.Render(
			infoStyle.Render("Google Workspace Setup") + "\n\n" +
				"1. Go to Google Cloud Console\n" +
				"2. APIs & Services → Credentials\n" +
				"3. Create OAuth 2.0 Client ID (Web application)\n" +
				"4. Add Authorized redirect URI:\n" +
				"   " + successStyle.Render("{your-vulcan-url}/users/auth/oidc/callback") + "\n" +
				"5. Copy Client ID and Client Secret"))
	}

	fmt.Println()

	// Collect OIDC settings
	var (
		providerTitle string
		issuerURL     string
		clientID      string
		clientSecret  string
		appURL        string
	)

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Provider display name").
				Description("Shown on the login button").
				Placeholder(selectedProvider).
				Value(&providerTitle),

			huh.NewInput().
				Title("Issuer URL").
				Description("Your identity provider's base URL").
				Placeholder(preset.IssuerHint).
				Value(&issuerURL),

			huh.NewInput().
				Title("Client ID").
				Description("From your identity provider").
				Value(&clientID),

			huh.NewInput().
				Title("Client Secret").
				Description("Keep this secure!").
				EchoMode(huh.EchoModePassword).
				Value(&clientSecret),

			huh.NewInput().
				Title("Your Vulcan URL").
				Description("Where Vulcan is accessible (for redirect URI)").
				Placeholder("https://vulcan.your-org.com").
				Value(&appURL),
		),
	)

	if err := form.Run(); err != nil {
		return
	}

	if providerTitle == "" {
		providerTitle = selectedProvider
	}

	// Validate inputs
	if issuerURL == "" || clientID == "" || clientSecret == "" {
		printError("Issuer URL, Client ID, and Client Secret are required")
		return
	}

	// Calculate redirect URI
	redirectURI := strings.TrimSuffix(appURL, "/") + "/users/auth/oidc/callback"

	// Show summary
	fmt.Println()
	fmt.Println(subtitleStyle.Render("Configuration Summary"))
	fmt.Printf("  Provider:     %s\n", infoStyle.Render(providerTitle))
	fmt.Printf("  Issuer:       %s\n", infoStyle.Render(issuerURL))
	fmt.Printf("  Client ID:    %s\n", infoStyle.Render(clientID))
	fmt.Printf("  Client Secret: %s\n", infoStyle.Render("(hidden)"))
	fmt.Printf("  Redirect URI: %s\n", infoStyle.Render(redirectURI))
	fmt.Println()

	var enableLocalLogin bool
	huh.NewConfirm().
		Title("Also allow local username/password login?").
		Description("Recommended for admin access if OIDC fails").
		Value(&enableLocalLogin).
		Run()

	var confirm bool
	huh.NewConfirm().
		Title("Save OIDC configuration?").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Configuration cancelled")
		return
	}

	// Update .env file
	vars, err := parseEnvFile(envPath)
	if err != nil {
		// Create new file if doesn't exist
		vars = []EnvVar{}
	}

	// Update or add OIDC settings
	updates := map[string]string{
		"VULCAN_ENABLE_OIDC":         "true",
		"VULCAN_OIDC_PROVIDER_TITLE": providerTitle,
		"VULCAN_OIDC_ISSUER_URL":     issuerURL,
		"VULCAN_OIDC_CLIENT_ID":      clientID,
		"VULCAN_OIDC_CLIENT_SECRET":  clientSecret,
		"VULCAN_OIDC_REDIRECT_URI":   redirectURI,
		"VULCAN_OIDC_DISCOVERY":      "true",
		"VULCAN_ENABLE_LOCAL_LOGIN":  fmt.Sprintf("%t", enableLocalLogin),
	}

	if appURL != "" {
		updates["VULCAN_APP_URL"] = appURL
	}

	vars = updateEnvVars(vars, updates)

	if err := writeEnvVars(envPath, vars); err != nil {
		printError("Failed to save configuration: " + err.Error())
		return
	}

	fmt.Println()
	printSuccess("OIDC configuration saved!")
	printInfo("Restart Vulcan for changes to take effect")
	fmt.Println()
	fmt.Println("  Make sure this redirect URI is configured in " + selectedProvider + ":")
	fmt.Println("  " + successStyle.Render(redirectURI))
}

func runAuthSetupLDAP(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	printTitle("LDAP Configuration")
	fmt.Println()

	// Show instructions
	instructionBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#3B82F6")).
		Padding(1, 2)

	fmt.Println(instructionBox.Render(
		infoStyle.Render("LDAP/Active Directory Setup") + "\n\n" +
			"You'll need:\n" +
			"• LDAP server hostname and port\n" +
			"• Base DN for user searches\n" +
			"• Bind DN (service account) and password\n" +
			"• User attribute mappings (optional)"))
	fmt.Println()

	var (
		ldapHost     string
		ldapPort     string
		ldapSSL      bool
		ldapBase     string
		ldapBindDN   string
		ldapPassword string
		ldapFilter   string
	)

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("LDAP Server Hostname").
				Placeholder("ldap.example.com").
				Value(&ldapHost),

			huh.NewInput().
				Title("LDAP Port").
				Description("389 for LDAP, 636 for LDAPS").
				Placeholder("636").
				Value(&ldapPort),

			huh.NewConfirm().
				Title("Use SSL/TLS?").
				Description("Recommended for production").
				Value(&ldapSSL),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("Base DN").
				Description("Where to search for users").
				Placeholder("dc=example,dc=com").
				Value(&ldapBase),

			huh.NewInput().
				Title("Bind DN").
				Description("Service account for LDAP queries").
				Placeholder("cn=vulcan-svc,ou=services,dc=example,dc=com").
				Value(&ldapBindDN),

			huh.NewInput().
				Title("Bind Password").
				EchoMode(huh.EchoModePassword).
				Value(&ldapPassword),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("User Filter (optional)").
				Description("LDAP filter for user searches").
				Placeholder("(objectClass=person)").
				Value(&ldapFilter),
		),
	)

	if err := form.Run(); err != nil {
		return
	}

	if ldapHost == "" || ldapBase == "" {
		printError("LDAP Host and Base DN are required")
		return
	}

	if ldapPort == "" {
		if ldapSSL {
			ldapPort = "636"
		} else {
			ldapPort = "389"
		}
	}

	if ldapFilter == "" {
		ldapFilter = "(objectClass=person)"
	}

	// Show summary
	fmt.Println()
	fmt.Println(subtitleStyle.Render("Configuration Summary"))
	fmt.Printf("  Server:   %s:%s\n", infoStyle.Render(ldapHost), infoStyle.Render(ldapPort))
	fmt.Printf("  SSL/TLS:  %s\n", infoStyle.Render(fmt.Sprintf("%t", ldapSSL)))
	fmt.Printf("  Base DN:  %s\n", infoStyle.Render(ldapBase))
	fmt.Printf("  Bind DN:  %s\n", infoStyle.Render(ldapBindDN))
	fmt.Printf("  Filter:   %s\n", infoStyle.Render(ldapFilter))
	fmt.Println()

	var enableLocalLogin bool
	huh.NewConfirm().
		Title("Also allow local username/password login?").
		Description("Recommended for admin access if LDAP fails").
		Value(&enableLocalLogin).
		Run()

	var confirm bool
	huh.NewConfirm().
		Title("Save LDAP configuration?").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Configuration cancelled")
		return
	}

	// Update .env file
	vars, err := parseEnvFile(envPath)
	if err != nil {
		vars = []EnvVar{}
	}

	method := "plain"
	if ldapSSL {
		method = "ssl"
	}

	updates := map[string]string{
		"VULCAN_ENABLE_LDAP":        "true",
		"VULCAN_LDAP_HOST":          ldapHost,
		"VULCAN_LDAP_PORT":          ldapPort,
		"VULCAN_LDAP_BASE":          ldapBase,
		"VULCAN_LDAP_BIND_DN":       ldapBindDN,
		"VULCAN_LDAP_ADMIN_PASS":    ldapPassword,
		"VULCAN_LDAP_METHOD":        method,
		"VULCAN_LDAP_UID":           "sAMAccountName",
		"VULCAN_ENABLE_LOCAL_LOGIN": fmt.Sprintf("%t", enableLocalLogin),
	}

	vars = updateEnvVars(vars, updates)

	if err := writeEnvVars(envPath, vars); err != nil {
		printError("Failed to save configuration: " + err.Error())
		return
	}

	fmt.Println()
	printSuccess("LDAP configuration saved!")
	printInfo("Restart Vulcan for changes to take effect")
}

func runAuthTest(cmd *cobra.Command, args []string) {
	printTitle("Test Authentication")
	fmt.Println()

	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		return
	}

	envMap := make(map[string]string)
	for _, v := range vars {
		if !v.IsComment {
			envMap[v.Key] = v.Value
		}
	}

	// Test OIDC
	if envMap["VULCAN_ENABLE_OIDC"] == "true" {
		fmt.Println(subtitleStyle.Render("Testing OIDC..."))
		issuer := envMap["VULCAN_OIDC_ISSUER_URL"]
		if issuer == "" {
			printError("OIDC Issuer URL not configured")
		} else {
			// Try to fetch OIDC discovery document
			discoveryURL := strings.TrimSuffix(issuer, "/") + "/.well-known/openid-configuration"
			printInfo("Discovery URL: " + discoveryURL)

			// Note: actual HTTP test would require net/http import
			// For now just validate the URL format
			if strings.HasPrefix(issuer, "https://") {
				printSuccess("Issuer URL uses HTTPS (good)")
			} else if strings.HasPrefix(issuer, "http://") {
				fmt.Printf("  %s Issuer URL uses HTTP (not recommended for production)\n", warningStyle.Render("⚠"))
			}

			if envMap["VULCAN_OIDC_CLIENT_ID"] != "" {
				printSuccess("Client ID configured")
			} else {
				printError("Client ID missing")
			}

			if envMap["VULCAN_OIDC_CLIENT_SECRET"] != "" {
				printSuccess("Client Secret configured")
			} else {
				printError("Client Secret missing")
			}
		}
		fmt.Println()
	}

	// Test LDAP
	if envMap["VULCAN_ENABLE_LDAP"] == "true" {
		fmt.Println(subtitleStyle.Render("Testing LDAP..."))
		host := envMap["VULCAN_LDAP_HOST"]
		if host == "" {
			printError("LDAP Host not configured")
		} else {
			port := envMap["VULCAN_LDAP_PORT"]
			if port == "" {
				port = "389"
			}
			printInfo(fmt.Sprintf("LDAP Server: %s:%s", host, port))

			if envMap["VULCAN_LDAP_BASE"] != "" {
				printSuccess("Base DN configured")
			} else {
				printError("Base DN missing")
			}

			if envMap["VULCAN_LDAP_BIND_DN"] != "" && envMap["VULCAN_LDAP_ADMIN_PASS"] != "" {
				printSuccess("Bind credentials configured")
			} else {
				fmt.Printf("  %s Bind credentials missing (may use anonymous bind)\n", warningStyle.Render("⚠"))
			}
		}
		fmt.Println()
	}

	printInfo("For a full test, try logging in via the web interface")
}

func runAuthDisable(cmd *cobra.Command, args []string) {
	provider := strings.ToLower(args[0])

	if provider != "oidc" && provider != "ldap" {
		printError("Unknown provider. Use 'oidc' or 'ldap'")
		return
	}

	projectRoot := GetProjectRoot()
	envPath := filepath.Join(projectRoot, ".env")

	vars, err := parseEnvFile(envPath)
	if err != nil {
		printError("Failed to read .env: " + err.Error())
		return
	}

	var confirm bool
	huh.NewConfirm().
		Title(fmt.Sprintf("Disable %s authentication?", strings.ToUpper(provider))).
		Description("Users will no longer be able to log in with this method").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	var key string
	switch provider {
	case "oidc":
		key = "VULCAN_ENABLE_OIDC"
	case "ldap":
		key = "VULCAN_ENABLE_LDAP"
	}

	vars = updateEnvVars(vars, map[string]string{key: "false"})

	if err := writeEnvVars(envPath, vars); err != nil {
		printError("Failed to save: " + err.Error())
		return
	}

	printSuccess(fmt.Sprintf("%s authentication disabled", strings.ToUpper(provider)))
	printInfo("Restart Vulcan for changes to take effect")
}

// updateEnvVars updates or adds environment variables
func updateEnvVars(vars []EnvVar, updates map[string]string) []EnvVar {
	updated := make(map[string]bool)

	// Update existing vars
	for i, v := range vars {
		if !v.IsComment {
			if newVal, ok := updates[v.Key]; ok {
				vars[i].Value = newVal
				updated[v.Key] = true
			}
		}
	}

	// Add new vars that weren't found
	for key, value := range updates {
		if !updated[key] {
			vars = append(vars, EnvVar{
				Key:      key,
				Value:    value,
				IsSecret: isSecret(key),
			})
		}
	}

	return vars
}

