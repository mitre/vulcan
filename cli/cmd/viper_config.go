package cmd

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// VulcanConfig holds all configuration for Vulcan CLI
type VulcanConfig struct {
	// Build configuration
	Build BuildSettings `mapstructure:"build"`

	// Port configuration
	Ports PortSettings `mapstructure:"ports"`

	// Docker configuration
	Docker DockerSettings `mapstructure:"docker"`

	// Database configuration
	Database DatabaseSettings `mapstructure:"database"`

	// Authentication configuration
	Auth AuthSettings `mapstructure:"auth"`

	// Application settings
	App AppSettings `mapstructure:"app"`
}

// BuildSettings holds build-related configuration
type BuildSettings struct {
	RubyVersion    string `mapstructure:"ruby_version"`
	NodeVersion    string `mapstructure:"node_version"`
	BundlerVersion string `mapstructure:"bundler_version"`
	Registry       string `mapstructure:"registry"`
	Image          string `mapstructure:"image"`
	Version        string `mapstructure:"version"`
}

// PortSettings holds port configuration
type PortSettings struct {
	Web        int `mapstructure:"web"`
	Database   int `mapstructure:"database"`
	Prometheus int `mapstructure:"prometheus"`
}

// DockerSettings holds Docker-specific configuration
type DockerSettings struct {
	Dockerfile string   `mapstructure:"dockerfile"`
	Platforms  []string `mapstructure:"platforms"`
	BuildArgs  map[string]string `mapstructure:"build_args"`
}

// DatabaseSettings holds database configuration
type DatabaseSettings struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Name     string `mapstructure:"name"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	URL      string `mapstructure:"url"`
}

// AuthSettings holds authentication configuration
type AuthSettings struct {
	LocalLogin       bool   `mapstructure:"local_login"`
	UserRegistration bool   `mapstructure:"user_registration"`
	SessionTimeout   int    `mapstructure:"session_timeout"`
	OIDC            OIDCSettings `mapstructure:"oidc"`
	LDAP            LDAPSettings `mapstructure:"ldap"`
}

// OIDCSettings holds OIDC/OAuth configuration
type OIDCSettings struct {
	Enabled      bool   `mapstructure:"enabled"`
	ProviderTitle string `mapstructure:"provider_title"`
	IssuerURL    string `mapstructure:"issuer_url"`
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
	RedirectURI  string `mapstructure:"redirect_uri"`
	Discovery    bool   `mapstructure:"discovery"`
}

// LDAPSettings holds LDAP configuration
type LDAPSettings struct {
	Enabled    bool   `mapstructure:"enabled"`
	Host       string `mapstructure:"host"`
	Port       int    `mapstructure:"port"`
	Base       string `mapstructure:"base"`
	BindDN     string `mapstructure:"bind_dn"`
	Password   string `mapstructure:"password"`
	Encryption string `mapstructure:"encryption"`
	Title      string `mapstructure:"title"`
	Attribute  string `mapstructure:"attribute"`
}

// AppSettings holds application-level settings
type AppSettings struct {
	URL          string `mapstructure:"url"`
	ContactEmail string `mapstructure:"contact_email"`
	WelcomeText  string `mapstructure:"welcome_text"`
	Environment  string `mapstructure:"environment"`
}

var cfgFile string
var viperConfig *viper.Viper

// InitConfig initializes the configuration system
func InitConfig() {
	viperConfig = viper.New()

	// Set defaults
	setDefaults(viperConfig)

	// Find project root
	projectRoot := GetProjectRoot()

	// Config file search paths
	viperConfig.AddConfigPath(projectRoot)
	viperConfig.AddConfigPath(".")
	viperConfig.AddConfigPath("$HOME/.vulcan")

	// Support multiple config file formats
	viperConfig.SetConfigName("vulcan") // vulcan.yaml, vulcan.json, vulcan.toml

	// Read .ruby-version if it exists
	rubyVersionPath := filepath.Join(projectRoot, ".ruby-version")
	if data, err := os.ReadFile(rubyVersionPath); err == nil {
		version := strings.TrimSpace(string(data))
		version = strings.TrimPrefix(version, "ruby-")
		if version != "" {
			viperConfig.Set("build.ruby_version", version)
		}
	}

	// Read config file if it exists
	if cfgFile != "" {
		viperConfig.SetConfigFile(cfgFile)
	}

	if err := viperConfig.ReadInConfig(); err == nil {
		// Config file found and read successfully
		fmt.Fprintln(os.Stderr, "Using config file:", viperConfig.ConfigFileUsed())
	}

	// Load .env file if it exists
	envPath := filepath.Join(projectRoot, ".env")
	if _, err := os.Stat(envPath); err == nil {
		loadDotEnv(envPath, viperConfig)
	}

	// Environment variables override everything
	// Bind env vars with VULCAN_ prefix
	viperConfig.SetEnvPrefix("VULCAN")
	viperConfig.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viperConfig.AutomaticEnv()

	// Also bind specific non-prefixed env vars for Docker compatibility
	bindDockerEnvVars(viperConfig)
}

// readVersionFile reads a version from a file like .ruby-version or .nvmrc
// Returns the version string trimmed of whitespace, or fallback if file doesn't exist
func readVersionFile(filename, fallback string) string {
	// Try current directory first, then walk up to find project root
	dirs := []string{".", "..", "../.."}
	for _, dir := range dirs {
		path := filepath.Join(dir, filename)
		data, err := os.ReadFile(path)
		if err == nil {
			version := strings.TrimSpace(string(data))
			if version != "" {
				return version
			}
		}
	}
	return fallback
}

// setDefaults sets all default configuration values
func setDefaults(v *viper.Viper) {
	// Build defaults - read from version files for single source of truth
	// Falls back to hardcoded values if files not found (e.g., running outside project)
	v.SetDefault("build.ruby_version", readVersionFile(".ruby-version", "3.4.7"))
	v.SetDefault("build.node_version", readVersionFile(".nvmrc", "24"))
	v.SetDefault("build.bundler_version", "2.6.5")
	v.SetDefault("build.registry", "mitre")
	v.SetDefault("build.image", "vulcan")
	v.SetDefault("build.version", "latest")

	// Port defaults
	v.SetDefault("ports.web", 3000)
	v.SetDefault("ports.database", 5432)
	v.SetDefault("ports.prometheus", 9394)

	// Docker defaults
	v.SetDefault("docker.dockerfile", "Dockerfile.production")
	v.SetDefault("docker.platforms", []string{"linux/amd64"})

	// Database defaults
	v.SetDefault("database.host", "localhost")
	v.SetDefault("database.port", 5432)
	v.SetDefault("database.name", "vulcan_development")
	v.SetDefault("database.user", "postgres")

	// Auth defaults
	v.SetDefault("auth.local_login", true)
	v.SetDefault("auth.user_registration", true)
	v.SetDefault("auth.session_timeout", 60)
	v.SetDefault("auth.oidc.enabled", false)
	v.SetDefault("auth.oidc.discovery", true)
	v.SetDefault("auth.ldap.enabled", false)
	v.SetDefault("auth.ldap.port", 389)

	// App defaults
	v.SetDefault("app.environment", "development")
	v.SetDefault("app.url", "http://localhost:3000")
	v.SetDefault("app.contact_email", "admin@example.com")
	v.SetDefault("app.welcome_text", "Welcome to Vulcan")
}

// loadDotEnv loads a .env file into Viper
func loadDotEnv(path string, v *viper.Viper) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()

	// Parse .env file
	envMap := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if idx := strings.Index(line, "="); idx > 0 {
			key := strings.TrimSpace(line[:idx])
			value := strings.TrimSpace(line[idx+1:])
			envMap[key] = value
		}
	}

	// Map .env keys to Viper config paths
	envToConfig := map[string]string{
		"PORT":                    "ports.web",
		"DATABASE_PORT":          "ports.database",
		"PROMETHEUS_PORT":        "ports.prometheus",
		"POSTGRES_PASSWORD":      "database.password",
		"DATABASE_URL":           "database.url",
		"VULCAN_IMAGE":           "build.image",
		"VULCAN_VERSION":         "build.version",
		"VULCAN_APP_URL":         "app.url",
		"VULCAN_CONTACT_EMAIL":   "app.contact_email",
		"VULCAN_WELCOME_TEXT":    "app.welcome_text",
		"VULCAN_ENABLE_OIDC":     "auth.oidc.enabled",
		"VULCAN_OIDC_ISSUER_URL": "auth.oidc.issuer_url",
		"VULCAN_OIDC_CLIENT_ID":  "auth.oidc.client_id",
		"VULCAN_OIDC_CLIENT_SECRET": "auth.oidc.client_secret",
		"VULCAN_OIDC_REDIRECT_URI":  "auth.oidc.redirect_uri",
		"VULCAN_OIDC_PROVIDER_TITLE": "auth.oidc.provider_title",
		"VULCAN_ENABLE_LDAP":     "auth.ldap.enabled",
		"VULCAN_LDAP_HOST":       "auth.ldap.host",
		"VULCAN_LDAP_PORT":       "auth.ldap.port",
		"VULCAN_LDAP_BASE":       "auth.ldap.base",
		"VULCAN_ENABLE_LOCAL_LOGIN": "auth.local_login",
		"VULCAN_ENABLE_USER_REGISTRATION": "auth.user_registration",
		"VULCAN_SESSION_TIMEOUT": "auth.session_timeout",
		"RAILS_ENV":              "app.environment",
	}

	for envKey, configKey := range envToConfig {
		if val, ok := envMap[envKey]; ok && val != "" {
			// Handle boolean conversions
			if strings.HasSuffix(envKey, "_ENABLED") || strings.HasPrefix(envKey, "VULCAN_ENABLE_") {
				v.Set(configKey, strings.ToLower(val) == "true")
			} else {
				v.Set(configKey, val)
			}
		}
	}
}

// bindDockerEnvVars binds standard Docker/Rails env vars
func bindDockerEnvVars(v *viper.Viper) {
	// These can be set without VULCAN_ prefix for Docker compatibility
	v.BindEnv("ports.web", "PORT")
	v.BindEnv("ports.database", "DATABASE_PORT")
	v.BindEnv("ports.prometheus", "PROMETHEUS_PORT")
	v.BindEnv("database.url", "DATABASE_URL")
	v.BindEnv("database.password", "POSTGRES_PASSWORD")
	v.BindEnv("app.environment", "RAILS_ENV")
}

// GetConfig returns the current configuration
func GetConfig() *VulcanConfig {
	var config VulcanConfig
	viperConfig.Unmarshal(&config)
	return &config
}

// GetViper returns the underlying Viper instance for advanced usage
func GetViper() *viper.Viper {
	return viperConfig
}

// AddConfigFlags adds config-related flags to a command
func AddConfigFlags(cmd *cobra.Command) {
	cmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default: vulcan.yaml)")
}

// WriteConfigFile writes current configuration to a file
func WriteConfigFile(path string, format string) error {
	if format == "" {
		format = "yaml"
	}

	switch format {
	case "yaml", "yml":
		return viperConfig.WriteConfigAs(path)
	case "json":
		return viperConfig.WriteConfigAs(path)
	case "toml":
		return viperConfig.WriteConfigAs(path)
	default:
		return fmt.Errorf("unsupported format: %s", format)
	}
}

