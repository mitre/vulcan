package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/viper"
)

func TestGetConfigDefaults(t *testing.T) {
	// Initialize config
	InitConfig()
	config := GetConfig()

	// Test build defaults
	if config.Build.RubyVersion == "" {
		t.Error("RubyVersion should have default")
	}
	if config.Build.NodeVersion != "24" {
		t.Errorf("NodeVersion = %s, want 24", config.Build.NodeVersion)
	}
	if config.Build.Registry != "mitre" {
		t.Errorf("Registry = %s, want mitre", config.Build.Registry)
	}
	if config.Build.Image != "vulcan" {
		t.Errorf("Image = %s, want vulcan", config.Build.Image)
	}

	// Test port defaults
	if config.Ports.Web != 3000 {
		t.Errorf("Ports.Web = %d, want 3000", config.Ports.Web)
	}
	if config.Ports.Database != 5432 {
		t.Errorf("Ports.Database = %d, want 5432", config.Ports.Database)
	}
	if config.Ports.Prometheus != 9394 {
		t.Errorf("Ports.Prometheus = %d, want 9394", config.Ports.Prometheus)
	}

	// Test auth defaults
	if !config.Auth.LocalLogin {
		t.Error("Auth.LocalLogin should default to true")
	}
	if config.Auth.SessionTimeout != 60 {
		t.Errorf("SessionTimeout = %d, want 60", config.Auth.SessionTimeout)
	}
}

func TestLoadDotEnv(t *testing.T) {
	// Create temp directory
	tmpDir := t.TempDir()

	// Create test .env file
	envContent := `PORT=4000
DATABASE_PORT=5433
PROMETHEUS_PORT=9395
VULCAN_APP_URL=https://test.example.com
`
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(envContent), 0600); err != nil {
		t.Fatal(err)
	}

	// Test loadDotEnv function
	v := GetViper()
	loadDotEnv(envPath, v)

	// Verify values loaded
	if v.GetInt("ports.web") != 4000 {
		t.Errorf("ports.web = %d, want 4000", v.GetInt("ports.web"))
	}
}

func TestConfigStructure(t *testing.T) {
	config := &VulcanConfig{}

	// Test nested struct initialization
	config.Build.RubyVersion = "3.3.9"
	config.Build.NodeVersion = "22"
	config.Ports.Web = 3000
	config.Auth.OIDC.Enabled = true
	config.Auth.LDAP.Port = 636

	if config.Build.RubyVersion != "3.3.9" {
		t.Error("Failed to set Build.RubyVersion")
	}
	if config.Auth.OIDC.Enabled != true {
		t.Error("Failed to set Auth.OIDC.Enabled")
	}
	if config.Auth.LDAP.Port != 636 {
		t.Error("Failed to set Auth.LDAP.Port")
	}
}

func TestGetBuildSettings(t *testing.T) {
	InitConfig()
	settings := getBuildSettings()

	if settings.RubyVersion == "" {
		t.Error("RubyVersion should not be empty")
	}
	if settings.Registry == "" {
		t.Error("Registry should not be empty")
	}
	if settings.Image == "" {
		t.Error("Image should not be empty")
	}
}

func TestGetPortSettings(t *testing.T) {
	InitConfig()
	ports := getPortSettings()

	if ports.Web <= 0 {
		t.Error("Web port should be positive")
	}
	if ports.Database <= 0 {
		t.Error("Database port should be positive")
	}
	if ports.Prometheus <= 0 {
		t.Error("Prometheus port should be positive")
	}
}

// ============================================================================
// Config File Format Tests
// ============================================================================

func TestLoadYAMLConfig(t *testing.T) {
	tmpDir := t.TempDir()
	yamlContent := `build:
  ruby_version: "3.2.0"
  node_version: "20"
  registry: "custom-registry"
  image: "custom-vulcan"
  version: "v1.0.0"

ports:
  web: 8080
  database: 5433
  prometheus: 9500

auth:
  local_login: false
  session_timeout: 120
`
	configPath := filepath.Join(tmpDir, "vulcan.yaml")
	if err := os.WriteFile(configPath, []byte(yamlContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)

	if err := v.ReadInConfig(); err != nil {
		t.Fatalf("Failed to read YAML config: %v", err)
	}

	// Verify YAML values loaded
	if v.GetString("build.ruby_version") != "3.2.0" {
		t.Errorf("build.ruby_version = %s, want 3.2.0", v.GetString("build.ruby_version"))
	}
	if v.GetString("build.registry") != "custom-registry" {
		t.Errorf("build.registry = %s, want custom-registry", v.GetString("build.registry"))
	}
	if v.GetInt("ports.web") != 8080 {
		t.Errorf("ports.web = %d, want 8080", v.GetInt("ports.web"))
	}
	if v.GetBool("auth.local_login") != false {
		t.Error("auth.local_login should be false")
	}
	if v.GetInt("auth.session_timeout") != 120 {
		t.Errorf("auth.session_timeout = %d, want 120", v.GetInt("auth.session_timeout"))
	}
}

func TestLoadJSONConfig(t *testing.T) {
	tmpDir := t.TempDir()
	jsonContent := `{
  "build": {
    "ruby_version": "3.1.0",
    "node_version": "18",
    "registry": "json-registry",
    "image": "json-vulcan"
  },
  "ports": {
    "web": 9000,
    "database": 5434
  }
}`
	configPath := filepath.Join(tmpDir, "vulcan.json")
	if err := os.WriteFile(configPath, []byte(jsonContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)

	if err := v.ReadInConfig(); err != nil {
		t.Fatalf("Failed to read JSON config: %v", err)
	}

	if v.GetString("build.ruby_version") != "3.1.0" {
		t.Errorf("build.ruby_version = %s, want 3.1.0", v.GetString("build.ruby_version"))
	}
	if v.GetString("build.registry") != "json-registry" {
		t.Errorf("build.registry = %s, want json-registry", v.GetString("build.registry"))
	}
	if v.GetInt("ports.web") != 9000 {
		t.Errorf("ports.web = %d, want 9000", v.GetInt("ports.web"))
	}
}

func TestLoadTOMLConfig(t *testing.T) {
	tmpDir := t.TempDir()
	tomlContent := `[build]
ruby_version = "3.0.0"
node_version = "16"
registry = "toml-registry"

[ports]
web = 7000
database = 5435
prometheus = 9600
`
	configPath := filepath.Join(tmpDir, "vulcan.toml")
	if err := os.WriteFile(configPath, []byte(tomlContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)

	if err := v.ReadInConfig(); err != nil {
		t.Fatalf("Failed to read TOML config: %v", err)
	}

	if v.GetString("build.ruby_version") != "3.0.0" {
		t.Errorf("build.ruby_version = %s, want 3.0.0", v.GetString("build.ruby_version"))
	}
	if v.GetString("build.registry") != "toml-registry" {
		t.Errorf("build.registry = %s, want toml-registry", v.GetString("build.registry"))
	}
	if v.GetInt("ports.web") != 7000 {
		t.Errorf("ports.web = %d, want 7000", v.GetInt("ports.web"))
	}
}

// ============================================================================
// Config Priority/Override Tests
// ============================================================================

func TestConfigPriorityDefaults(t *testing.T) {
	// Test that defaults are set correctly
	v := viper.New()
	setDefaults(v)

	// Version defaults are read from .ruby-version and .nvmrc files
	// They should be non-empty (either from files or fallback values)
	if v.GetString("build.ruby_version") == "" {
		t.Error("default ruby_version should not be empty")
	}
	if v.GetString("build.node_version") == "" {
		t.Error("default node_version should not be empty")
	}
	// These are static defaults
	if v.GetString("build.registry") != "mitre" {
		t.Errorf("default registry = %s, want mitre", v.GetString("build.registry"))
	}
	if v.GetInt("ports.web") != 3000 {
		t.Errorf("default ports.web = %d, want 3000", v.GetInt("ports.web"))
	}
}

func TestConfigPriorityFileOverridesDefaults(t *testing.T) {
	tmpDir := t.TempDir()
	yamlContent := `build:
  ruby_version: "3.2.5"
ports:
  web: 4000
`
	configPath := filepath.Join(tmpDir, "vulcan.yaml")
	if err := os.WriteFile(configPath, []byte(yamlContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)
	v.ReadInConfig()

	// Config file should override defaults
	if v.GetString("build.ruby_version") != "3.2.5" {
		t.Errorf("ruby_version = %s, want 3.2.5 (from config file)", v.GetString("build.ruby_version"))
	}
	if v.GetInt("ports.web") != 4000 {
		t.Errorf("ports.web = %d, want 4000 (from config file)", v.GetInt("ports.web"))
	}

	// Defaults should still apply to non-overridden values (from .nvmrc or fallback)
	if v.GetString("build.node_version") == "" {
		t.Error("node_version should not be empty (from default)")
	}
}

func TestConfigPriorityEnvOverridesFile(t *testing.T) {
	tmpDir := t.TempDir()
	yamlContent := `build:
  ruby_version: "3.2.5"
ports:
  web: 4000
`
	configPath := filepath.Join(tmpDir, "vulcan.yaml")
	if err := os.WriteFile(configPath, []byte(yamlContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)
	v.ReadInConfig()

	// Set env prefix and bind
	v.SetEnvPrefix("VULCAN")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	// Set environment variable
	os.Setenv("VULCAN_BUILD_RUBY_VERSION", "3.3.0")
	defer os.Unsetenv("VULCAN_BUILD_RUBY_VERSION")

	// Env should override config file
	if v.GetString("build.ruby_version") != "3.3.0" {
		t.Errorf("ruby_version = %s, want 3.3.0 (from env)", v.GetString("build.ruby_version"))
	}

	// Config file value should still apply for non-env-set values
	if v.GetInt("ports.web") != 4000 {
		t.Errorf("ports.web = %d, want 4000 (from config file)", v.GetInt("ports.web"))
	}
}

// ============================================================================
// loadDotEnv Comprehensive Tests
// ============================================================================

func TestLoadDotEnvAllMappings(t *testing.T) {
	tmpDir := t.TempDir()
	envContent := `# Port mappings
PORT=4000
DATABASE_PORT=5433
PROMETHEUS_PORT=9395

# Database
POSTGRES_PASSWORD=secret123
DATABASE_URL=postgres://user:pass@localhost:5432/vulcan

# Image config
VULCAN_IMAGE=custom-image
VULCAN_VERSION=v2.0.0

# App settings
VULCAN_APP_URL=https://vulcan.example.com
VULCAN_CONTACT_EMAIL=admin@example.com
VULCAN_WELCOME_TEXT=Welcome to Custom Vulcan

# Auth settings
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://auth.example.com
VULCAN_OIDC_CLIENT_ID=vulcan-client
VULCAN_OIDC_CLIENT_SECRET=client-secret
VULCAN_OIDC_REDIRECT_URI=https://vulcan.example.com/callback
VULCAN_OIDC_PROVIDER_TITLE=Example Auth

VULCAN_ENABLE_LDAP=true
VULCAN_LDAP_HOST=ldap.example.com
VULCAN_LDAP_PORT=636
VULCAN_LDAP_BASE=dc=example,dc=com

VULCAN_ENABLE_LOCAL_LOGIN=false
VULCAN_ENABLE_USER_REGISTRATION=false
VULCAN_SESSION_TIMEOUT=30

# Rails env
RAILS_ENV=production
`
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(envContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	loadDotEnv(envPath, v)

	// Port mappings
	if v.GetInt("ports.web") != 4000 {
		t.Errorf("ports.web = %d, want 4000", v.GetInt("ports.web"))
	}
	if v.GetInt("ports.database") != 5433 {
		t.Errorf("ports.database = %d, want 5433", v.GetInt("ports.database"))
	}
	if v.GetInt("ports.prometheus") != 9395 {
		t.Errorf("ports.prometheus = %d, want 9395", v.GetInt("ports.prometheus"))
	}

	// Database
	if v.GetString("database.password") != "secret123" {
		t.Errorf("database.password = %s, want secret123", v.GetString("database.password"))
	}
	if v.GetString("database.url") != "postgres://user:pass@localhost:5432/vulcan" {
		t.Errorf("database.url mismatch")
	}

	// Image config
	if v.GetString("build.image") != "custom-image" {
		t.Errorf("build.image = %s, want custom-image", v.GetString("build.image"))
	}
	if v.GetString("build.version") != "v2.0.0" {
		t.Errorf("build.version = %s, want v2.0.0", v.GetString("build.version"))
	}

	// App settings
	if v.GetString("app.url") != "https://vulcan.example.com" {
		t.Errorf("app.url mismatch")
	}
	if v.GetString("app.contact_email") != "admin@example.com" {
		t.Errorf("app.contact_email mismatch")
	}
	if v.GetString("app.welcome_text") != "Welcome to Custom Vulcan" {
		t.Errorf("app.welcome_text mismatch")
	}

	// OIDC settings
	if v.GetBool("auth.oidc.enabled") != true {
		t.Error("auth.oidc.enabled should be true")
	}
	if v.GetString("auth.oidc.issuer_url") != "https://auth.example.com" {
		t.Errorf("auth.oidc.issuer_url mismatch")
	}
	if v.GetString("auth.oidc.client_id") != "vulcan-client" {
		t.Errorf("auth.oidc.client_id mismatch")
	}

	// LDAP settings
	if v.GetBool("auth.ldap.enabled") != true {
		t.Error("auth.ldap.enabled should be true")
	}
	if v.GetString("auth.ldap.host") != "ldap.example.com" {
		t.Errorf("auth.ldap.host mismatch")
	}
	if v.GetString("auth.ldap.port") != "636" {
		t.Errorf("auth.ldap.port = %s, want 636", v.GetString("auth.ldap.port"))
	}

	// Auth settings
	if v.GetBool("auth.local_login") != false {
		t.Error("auth.local_login should be false")
	}
	if v.GetBool("auth.user_registration") != false {
		t.Error("auth.user_registration should be false")
	}
	if v.GetString("auth.session_timeout") != "30" {
		t.Errorf("auth.session_timeout = %s, want 30", v.GetString("auth.session_timeout"))
	}

	// Rails env
	if v.GetString("app.environment") != "production" {
		t.Errorf("app.environment = %s, want production", v.GetString("app.environment"))
	}
}

func TestLoadDotEnvComments(t *testing.T) {
	tmpDir := t.TempDir()
	envContent := `# This is a comment
PORT=5000
# Another comment
# PORT=6000
DATABASE_PORT=5432
`
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(envContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	loadDotEnv(envPath, v)

	// Should use uncommented value
	if v.GetInt("ports.web") != 5000 {
		t.Errorf("ports.web = %d, want 5000", v.GetInt("ports.web"))
	}
}

func TestLoadDotEnvEmptyValues(t *testing.T) {
	tmpDir := t.TempDir()
	envContent := `PORT=
DATABASE_PORT=5432
VULCAN_APP_URL=
`
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(envContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	loadDotEnv(envPath, v)

	// Empty values should not override defaults
	if v.GetInt("ports.web") != 3000 {
		t.Errorf("ports.web = %d, want 3000 (default, empty value ignored)", v.GetInt("ports.web"))
	}
	// Non-empty should override
	if v.GetInt("ports.database") != 5432 {
		t.Errorf("ports.database = %d, want 5432", v.GetInt("ports.database"))
	}
}

// ============================================================================
// WriteConfigFile Tests
// ============================================================================

func TestWriteConfigFileYAML(t *testing.T) {
	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "output.yaml")

	InitConfig()
	v := GetViper()

	// Set some values
	v.Set("build.ruby_version", "3.3.9")
	v.Set("ports.web", 8080)

	err := WriteConfigFile(outputPath, "yaml")
	if err != nil {
		t.Fatalf("WriteConfigFile failed: %v", err)
	}

	// Verify file exists
	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("Output file was not created")
	}

	// Read and verify content
	content, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("Failed to read output file: %v", err)
	}

	if !strings.Contains(string(content), "ruby_version") {
		t.Error("Output file should contain ruby_version")
	}
}

func TestWriteConfigFileJSON(t *testing.T) {
	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "output.json")

	InitConfig()

	err := WriteConfigFile(outputPath, "json")
	if err != nil {
		t.Fatalf("WriteConfigFile failed: %v", err)
	}

	// Verify file exists
	if _, err := os.Stat(outputPath); os.IsNotExist(err) {
		t.Error("Output file was not created")
	}
}

func TestWriteConfigFileUnsupportedFormat(t *testing.T) {
	tmpDir := t.TempDir()
	outputPath := filepath.Join(tmpDir, "output.xyz")

	InitConfig()

	err := WriteConfigFile(outputPath, "xyz")
	if err == nil {
		t.Error("WriteConfigFile should fail for unsupported format")
	}
	if !strings.Contains(err.Error(), "unsupported format") {
		t.Errorf("Error message should mention unsupported format: %v", err)
	}
}

// ============================================================================
// CLI Flag Override Tests
// ============================================================================

func TestBuildSettingsCLIOverrides(t *testing.T) {
	InitConfig()

	// Save original flag values
	origRubyVersion := buildRubyVersion
	origNodeVersion := buildNodeVersion
	origRegistry := buildRegistry
	origImageName := buildImageName
	origVersion := buildVersion

	// Set CLI flag values
	buildRubyVersion = "3.1.0"
	buildNodeVersion = "18"
	buildRegistry = "cli-registry"
	buildImageName = "cli-image"
	buildVersion = "cli-version"

	// Cleanup after test
	defer func() {
		buildRubyVersion = origRubyVersion
		buildNodeVersion = origNodeVersion
		buildRegistry = origRegistry
		buildImageName = origImageName
		buildVersion = origVersion
	}()

	settings := getBuildSettings()

	if settings.RubyVersion != "3.1.0" {
		t.Errorf("RubyVersion = %s, want 3.1.0 (CLI override)", settings.RubyVersion)
	}
	if settings.NodeVersion != "18" {
		t.Errorf("NodeVersion = %s, want 18 (CLI override)", settings.NodeVersion)
	}
	if settings.Registry != "cli-registry" {
		t.Errorf("Registry = %s, want cli-registry (CLI override)", settings.Registry)
	}
	if settings.Image != "cli-image" {
		t.Errorf("Image = %s, want cli-image (CLI override)", settings.Image)
	}
	if settings.Version != "cli-version" {
		t.Errorf("Version = %s, want cli-version (CLI override)", settings.Version)
	}
}

func TestPortSettingsCLIOverrides(t *testing.T) {
	InitConfig()

	// Save original flag values
	origWebPort := buildWebPort
	origPrometheusPort := buildPrometheusPort

	// Set CLI flag values
	buildWebPort = "9000"
	buildPrometheusPort = "9500"

	// Cleanup after test
	defer func() {
		buildWebPort = origWebPort
		buildPrometheusPort = origPrometheusPort
	}()

	ports := getPortSettings()

	if ports.Web != 9000 {
		t.Errorf("Web = %d, want 9000 (CLI override)", ports.Web)
	}
	if ports.Prometheus != 9500 {
		t.Errorf("Prometheus = %d, want 9500 (CLI override)", ports.Prometheus)
	}
}

func TestPortSettingsInvalidCLIValues(t *testing.T) {
	InitConfig()

	// Save original flag values
	origWebPort := buildWebPort

	// Set invalid CLI value
	buildWebPort = "not-a-number"

	// Cleanup after test
	defer func() {
		buildWebPort = origWebPort
	}()

	ports := getPortSettings()

	// Should use default when CLI value is invalid
	if ports.Web != 3000 {
		t.Errorf("Web = %d, want 3000 (default, invalid CLI ignored)", ports.Web)
	}
}

// ============================================================================
// Edge Cases
// ============================================================================

func TestMissingConfigFile(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	// Try to read non-existent file - should not panic
	v.SetConfigFile("/nonexistent/vulcan.yaml")
	err := v.ReadInConfig()

	// Error is expected, but defaults should still work
	if err == nil {
		t.Error("Expected error for missing config file")
	}

	// Defaults should still be set (from .ruby-version file or fallback)
	if v.GetString("build.ruby_version") == "" {
		t.Error("Defaults should still work: ruby_version should not be empty")
	}
}

func TestMalformedYAMLConfig(t *testing.T) {
	tmpDir := t.TempDir()
	malformedContent := `build:
  ruby_version: "3.2.0"
  node_version: [invalid yaml
    this is broken
`
	configPath := filepath.Join(tmpDir, "vulcan.yaml")
	if err := os.WriteFile(configPath, []byte(malformedContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)

	err := v.ReadInConfig()
	if err == nil {
		t.Error("Expected error for malformed YAML")
	}

	// Defaults should still be available (from .ruby-version file or fallback)
	if v.GetString("build.ruby_version") == "" {
		t.Error("Defaults should still work: ruby_version should not be empty")
	}
}

func TestMalformedJSONConfig(t *testing.T) {
	tmpDir := t.TempDir()
	malformedContent := `{
  "build": {
    "ruby_version": "3.2.0",
    invalid json here
  }
}`
	configPath := filepath.Join(tmpDir, "vulcan.json")
	if err := os.WriteFile(configPath, []byte(malformedContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	v.SetConfigFile(configPath)

	err := v.ReadInConfig()
	if err == nil {
		t.Error("Expected error for malformed JSON")
	}
}

func TestMissingDotEnvFile(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	// Should not panic when .env file doesn't exist
	loadDotEnv("/nonexistent/.env", v)

	// Defaults should still work
	if v.GetInt("ports.web") != 3000 {
		t.Errorf("ports.web = %d, want 3000", v.GetInt("ports.web"))
	}
}

func TestEmptyDotEnvFile(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(""), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	loadDotEnv(envPath, v)

	// Defaults should still work
	if v.GetInt("ports.web") != 3000 {
		t.Errorf("ports.web = %d, want 3000", v.GetInt("ports.web"))
	}
}

func TestDotEnvWithSpaces(t *testing.T) {
	tmpDir := t.TempDir()
	envContent := `  PORT = 4500
DATABASE_PORT=  5433
  VULCAN_APP_URL=  https://example.com
`
	envPath := filepath.Join(tmpDir, ".env")
	if err := os.WriteFile(envPath, []byte(envContent), 0600); err != nil {
		t.Fatal(err)
	}

	v := viper.New()
	setDefaults(v)
	loadDotEnv(envPath, v)

	// Values should be trimmed
	if v.GetInt("ports.web") != 4500 {
		t.Errorf("ports.web = %d, want 4500", v.GetInt("ports.web"))
	}
}

func TestGetViperReturnsInstance(t *testing.T) {
	InitConfig()
	v := GetViper()

	if v == nil {
		t.Error("GetViper should return non-nil instance")
	}
}

func TestGetConfigReturnsStruct(t *testing.T) {
	InitConfig()
	config := GetConfig()

	if config == nil {
		t.Error("GetConfig should return non-nil struct")
	}
}

// ============================================================================
// Database Settings Tests
// ============================================================================

func TestDatabaseDefaults(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	if v.GetString("database.host") != "localhost" {
		t.Errorf("database.host = %s, want localhost", v.GetString("database.host"))
	}
	if v.GetInt("database.port") != 5432 {
		t.Errorf("database.port = %d, want 5432", v.GetInt("database.port"))
	}
	if v.GetString("database.name") != "vulcan_development" {
		t.Errorf("database.name = %s, want vulcan_development", v.GetString("database.name"))
	}
	if v.GetString("database.user") != "postgres" {
		t.Errorf("database.user = %s, want postgres", v.GetString("database.user"))
	}
}

// ============================================================================
// Docker Settings Tests
// ============================================================================

func TestDockerDefaults(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	if v.GetString("docker.dockerfile") != "Dockerfile" {
		t.Errorf("docker.dockerfile = %s, want Dockerfile", v.GetString("docker.dockerfile"))
	}

	if v.GetString("docker.target") != "production" {
		t.Errorf("docker.target = %s, want production", v.GetString("docker.target"))
	}

	platforms := v.GetStringSlice("docker.platforms")
	if len(platforms) != 1 || platforms[0] != "linux/amd64" {
		t.Errorf("docker.platforms = %v, want [linux/amd64]", platforms)
	}
}

// ============================================================================
// App Settings Tests
// ============================================================================

func TestAppDefaults(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	if v.GetString("app.environment") != "development" {
		t.Errorf("app.environment = %s, want development", v.GetString("app.environment"))
	}
	if v.GetString("app.url") != "http://localhost:3000" {
		t.Errorf("app.url = %s, want http://localhost:3000", v.GetString("app.url"))
	}
	if v.GetString("app.contact_email") != "admin@example.com" {
		t.Errorf("app.contact_email = %s, want admin@example.com", v.GetString("app.contact_email"))
	}
	if v.GetString("app.welcome_text") != "Welcome to Vulcan" {
		t.Errorf("app.welcome_text = %s, want Welcome to Vulcan", v.GetString("app.welcome_text"))
	}
}

// ============================================================================
// OIDC Settings Tests
// ============================================================================

func TestOIDCDefaults(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	if v.GetBool("auth.oidc.enabled") != false {
		t.Error("auth.oidc.enabled should default to false")
	}
	if v.GetBool("auth.oidc.discovery") != true {
		t.Error("auth.oidc.discovery should default to true")
	}
}

// ============================================================================
// LDAP Settings Tests
// ============================================================================

func TestLDAPDefaults(t *testing.T) {
	v := viper.New()
	setDefaults(v)

	if v.GetBool("auth.ldap.enabled") != false {
		t.Error("auth.ldap.enabled should default to false")
	}
	if v.GetInt("auth.ldap.port") != 389 {
		t.Errorf("auth.ldap.port = %d, want 389", v.GetInt("auth.ldap.port"))
	}
}
