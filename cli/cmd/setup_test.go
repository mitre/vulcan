package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetupConfigDefaults(t *testing.T) {
	config := &SetupConfig{}

	// Test that config starts empty
	if config.Environment != "" {
		t.Error("Environment should be empty by default")
	}
	if config.PostgresPassword != "" {
		t.Error("PostgresPassword should be empty by default")
	}
}

func TestSetupConfigDevDefaults(t *testing.T) {
	config := &SetupConfig{
		Environment:      "development",
		PostgresPassword: "postgres",
		SecretKeyBase:    "development_secret_key_base_not_for_production_use",
		CipherPassword:   "development_cipher_password_not_for_production_use",
		CipherSalt:       "development_cipher_salt_not_for_production_use",
		EnableLocalAuth:  true,
		AppURL:           "http://localhost:3000",
		ContactEmail:     "admin@example.com",
		WelcomeText:      "Welcome to Vulcan Development",
	}

	// Verify development defaults
	if config.Environment != "development" {
		t.Errorf("Expected development, got %s", config.Environment)
	}
	if config.PostgresPassword != "postgres" {
		t.Error("Expected postgres password to be 'postgres' for dev")
	}
	if !config.EnableLocalAuth {
		t.Error("Local auth should be enabled for dev")
	}
	if config.AppURL != "http://localhost:3000" {
		t.Error("App URL should be localhost:3000 for dev")
	}
}

func TestSetupConfigProductionSecrets(t *testing.T) {
	// Test that production secrets are unique
	password1 := generateSecureToken(33)
	password2 := generateSecureToken(33)

	if password1 == password2 {
		t.Error("Generated tokens should be unique")
	}

	// Test minimum length
	if len(password1) < 60 {
		t.Errorf("Token should be at least 60 chars, got %d", len(password1))
	}
}

func TestSetupConfigOIDCSettings(t *testing.T) {
	config := &SetupConfig{
		AuthMethod:        "oidc",
		OIDCProviderTitle: "Test Provider",
		OIDCIssuerURL:     "https://test.okta.com",
		OIDCClientID:      "test-client-id",
		OIDCClientSecret:  "test-client-secret",
		AppURL:            "https://vulcan.example.com",
	}

	// Set redirect URI based on app URL (like the wizard does)
	config.OIDCRedirectURI = config.AppURL + "/users/auth/oidc/callback"

	// Verify OIDC settings
	if config.AuthMethod != "oidc" {
		t.Error("Auth method should be oidc")
	}
	if config.OIDCRedirectURI != "https://vulcan.example.com/users/auth/oidc/callback" {
		t.Errorf("Unexpected redirect URI: %s", config.OIDCRedirectURI)
	}
}

func TestSetupConfigLDAPSettings(t *testing.T) {
	config := &SetupConfig{
		AuthMethod:   "ldap",
		LDAPHost:     "ldap.example.com",
		LDAPPort:     "636",
		LDAPBase:     "dc=example,dc=com",
		LDAPBindDN:   "cn=admin,dc=example,dc=com",
		LDAPPassword: "ldap-password",
	}

	if config.AuthMethod != "ldap" {
		t.Error("Auth method should be ldap")
	}
	if config.LDAPPort != "636" {
		t.Error("LDAP port should be 636 (LDAPS)")
	}
}

func TestWriteEnvFileCreation(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	config := &SetupConfig{
		Environment:      "development",
		PostgresPassword: "test-password",
		SecretKeyBase:    "test-secret-key-base",
		CipherPassword:   "test-cipher-password",
		CipherSalt:       "test-cipher-salt",
		EnableLocalAuth:  true,
		AppURL:           "http://localhost:3000",
		ContactEmail:     "test@example.com",
		WelcomeText:      "Test Welcome",
	}

	writeEnvFile(config, envPath)

	// Verify file was created
	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		t.Fatal("Env file was not created")
	}

	// Verify file permissions
	info, _ := os.Stat(envPath)
	mode := info.Mode().Perm()
	if mode != 0600 {
		t.Errorf("Expected 0600 permissions, got %o", mode)
	}

	// Read and verify contents
	data, err := os.ReadFile(envPath)
	if err != nil {
		t.Fatalf("Failed to read env file: %v", err)
	}

	content := string(data)

	// Check for expected content
	expectedStrings := []string{
		"POSTGRES_PASSWORD=test-password",
		"SECRET_KEY_BASE=test-secret-key-base",
		"CIPHER_PASSWORD=test-cipher-password",
		"CIPHER_SALT=test-cipher-salt",
		"VULCAN_APP_URL=http://localhost:3000",
		"VULCAN_CONTACT_EMAIL=test@example.com",
	}

	for _, expected := range expectedStrings {
		if !strings.Contains(content, expected) {
			t.Errorf("Expected env file to contain: %s", expected)
		}
	}
}

func TestWriteEnvFileWithOIDC(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	config := &SetupConfig{
		Environment:       "production",
		PostgresPassword:  "prod-password",
		SecretKeyBase:     "prod-secret-key-base",
		CipherPassword:    "prod-cipher-password",
		CipherSalt:        "prod-cipher-salt",
		AuthMethod:        "oidc",
		EnableLocalAuth:   false,
		OIDCProviderTitle: "Okta",
		OIDCIssuerURL:     "https://example.okta.com",
		OIDCClientID:      "client-123",
		OIDCClientSecret:  "secret-456",
		OIDCRedirectURI:   "https://vulcan.example.com/users/auth/oidc/callback",
		AppURL:            "https://vulcan.example.com",
		ContactEmail:      "admin@example.com",
		WelcomeText:       "Welcome",
	}

	writeEnvFile(config, envPath)

	data, _ := os.ReadFile(envPath)
	content := string(data)

	// Check OIDC settings are present
	expectedOIDC := []string{
		"VULCAN_ENABLE_OIDC=true",
		"VULCAN_OIDC_PROVIDER_TITLE=Okta",
		"VULCAN_OIDC_ISSUER_URL=https://example.okta.com",
		"VULCAN_OIDC_CLIENT_ID=client-123",
		"VULCAN_OIDC_DISCOVERY=true",
	}

	for _, expected := range expectedOIDC {
		if !strings.Contains(content, expected) {
			t.Errorf("Expected env file to contain: %s", expected)
		}
	}

	// Check production settings
	if !strings.Contains(content, "RAILS_ENV=production") {
		t.Error("Production env should have RAILS_ENV=production")
	}
}

func TestWriteEnvFileWithLDAP(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	config := &SetupConfig{
		Environment:      "production",
		PostgresPassword: "prod-password",
		SecretKeyBase:    "prod-secret-key-base",
		CipherPassword:   "prod-cipher-password",
		CipherSalt:       "prod-cipher-salt",
		AuthMethod:       "ldap",
		EnableLocalAuth:  true,
		LDAPHost:         "ldap.example.com",
		LDAPPort:         "636",
		LDAPBase:         "dc=example,dc=com",
		LDAPBindDN:       "cn=admin,dc=example,dc=com",
		LDAPPassword:     "ldap-pass",
		AppURL:           "https://vulcan.example.com",
		ContactEmail:     "admin@example.com",
		WelcomeText:      "Welcome",
	}

	writeEnvFile(config, envPath)

	data, _ := os.ReadFile(envPath)
	content := string(data)

	// Check LDAP settings are present
	expectedLDAP := []string{
		"VULCAN_ENABLE_LDAP=true",
		"VULCAN_LDAP_HOST=ldap.example.com",
		"VULCAN_LDAP_PORT=636",
		"VULCAN_LDAP_BASE=dc=example,dc=com",
	}

	for _, expected := range expectedLDAP {
		if !strings.Contains(content, expected) {
			t.Errorf("Expected env file to contain: %s", expected)
		}
	}
}

func TestSetupDryRunFlag(t *testing.T) {
	// Test that the dry-run flag is defined
	flag := setupCmd.Flags().Lookup("dry-run")
	if flag == nil {
		t.Fatal("--dry-run flag should be defined")
	}

	if flag.DefValue != "false" {
		t.Errorf("--dry-run default should be false, got %s", flag.DefValue)
	}
}

func TestEnvironmentDetectionDev(t *testing.T) {
	// Simulating arg parsing for "dev"
	arg := "dev"
	var env string

	switch strings.ToLower(arg) {
	case "dev", "development":
		env = "development"
	case "prod", "production":
		env = "production"
	}

	if env != "development" {
		t.Errorf("Expected development, got %s", env)
	}
}

func TestEnvironmentDetectionProd(t *testing.T) {
	// Simulating arg parsing for "prod"
	variants := []string{"prod", "production", "PROD", "PRODUCTION"}

	for _, arg := range variants {
		var env string
		switch strings.ToLower(arg) {
		case "dev", "development":
			env = "development"
		case "prod", "production":
			env = "production"
		}

		if env != "production" {
			t.Errorf("For arg '%s': expected production, got %s", arg, env)
		}
	}
}
