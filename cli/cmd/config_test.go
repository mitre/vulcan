package cmd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsSecret(t *testing.T) {
	tests := []struct {
		key      string
		expected bool
	}{
		{"POSTGRES_PASSWORD", true},
		{"SECRET_KEY_BASE", true},
		{"DATABASE_URL", false},
		{"RAILS_ENV", false},
		{"CIPHER_PASSWORD", true},
		{"CIPHER_SALT", true},
		{"VULCAN_OIDC_CLIENT_SECRET", true},
		{"LDAP_PASSWORD", true},
		{"SMTP_PASSWORD", true},
		{"VULCAN_APP_URL", false},
		{"API_TOKEN", true},
		{"PRIVATE_KEY", true},
	}

	for _, tt := range tests {
		t.Run(tt.key, func(t *testing.T) {
			result := isSecret(tt.key)
			if result != tt.expected {
				t.Errorf("isSecret(%s) = %v, expected %v", tt.key, result, tt.expected)
			}
		})
	}
}

func TestParseEnvFile(t *testing.T) {
	// Create a temporary .env file
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	content := `# Test environment file
# Database settings
POSTGRES_PASSWORD=secret123
DATABASE_URL=postgres://localhost/test

# Application
RAILS_ENV=development
SECRET_KEY_BASE=verylongsecretkey

# Empty line below

VULCAN_APP_URL=http://localhost:3000
`

	err := os.WriteFile(envPath, []byte(content), 0600)
	if err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	vars, err := parseEnvFile(envPath)
	if err != nil {
		t.Fatalf("Failed to parse env file: %v", err)
	}

	// Count actual variables (non-comments)
	varCount := 0
	for _, v := range vars {
		if !v.IsComment {
			varCount++
		}
	}

	if varCount != 5 {
		t.Errorf("Expected 5 variables, got %d", varCount)
	}

	// Check specific values
	varMap := make(map[string]EnvVar)
	for _, v := range vars {
		if !v.IsComment {
			varMap[v.Key] = v
		}
	}

	if v, ok := varMap["POSTGRES_PASSWORD"]; !ok {
		t.Error("POSTGRES_PASSWORD not found")
	} else if v.Value != "secret123" {
		t.Errorf("POSTGRES_PASSWORD = %s, expected secret123", v.Value)
	} else if !v.IsSecret {
		t.Error("POSTGRES_PASSWORD should be marked as secret")
	}

	if v, ok := varMap["RAILS_ENV"]; !ok {
		t.Error("RAILS_ENV not found")
	} else if v.IsSecret {
		t.Error("RAILS_ENV should not be marked as secret")
	}
}

func TestWriteEnvVars(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	vars := []EnvVar{
		{Raw: "# Test file", IsComment: true},
		{Key: "DATABASE_URL", Value: "postgres://localhost/test"},
		{Key: "SECRET_KEY_BASE", Value: "mysecret", IsSecret: true},
		{Raw: "", IsComment: true},
		{Key: "RAILS_ENV", Value: "production"},
	}

	err := writeEnvVars(envPath, vars)
	if err != nil {
		t.Fatalf("Failed to write env file: %v", err)
	}

	// Verify file was created with correct permissions
	info, err := os.Stat(envPath)
	if err != nil {
		t.Fatalf("File not created: %v", err)
	}

	mode := info.Mode().Perm()
	if mode != 0600 {
		t.Errorf("File permissions = %o, expected 0600", mode)
	}

	// Read it back
	parsedVars, err := parseEnvFile(envPath)
	if err != nil {
		t.Fatalf("Failed to parse written file: %v", err)
	}

	// Find the values
	varMap := make(map[string]string)
	for _, v := range parsedVars {
		if !v.IsComment {
			varMap[v.Key] = v.Value
		}
	}

	if varMap["DATABASE_URL"] != "postgres://localhost/test" {
		t.Error("DATABASE_URL not preserved correctly")
	}

	if varMap["SECRET_KEY_BASE"] != "mysecret" {
		t.Error("SECRET_KEY_BASE not preserved correctly")
	}
}

func TestUpdateEnvVars(t *testing.T) {
	vars := []EnvVar{
		{Key: "EXISTING_VAR", Value: "old_value"},
		{Key: "UNCHANGED_VAR", Value: "unchanged"},
	}

	updates := map[string]string{
		"EXISTING_VAR": "new_value",
		"NEW_VAR":      "brand_new",
	}

	result := updateEnvVars(vars, updates)

	varMap := make(map[string]string)
	for _, v := range result {
		if !v.IsComment {
			varMap[v.Key] = v.Value
		}
	}

	if varMap["EXISTING_VAR"] != "new_value" {
		t.Error("EXISTING_VAR should be updated to new_value")
	}

	if varMap["UNCHANGED_VAR"] != "unchanged" {
		t.Error("UNCHANGED_VAR should remain unchanged")
	}

	if varMap["NEW_VAR"] != "brand_new" {
		t.Error("NEW_VAR should be added")
	}
}

func TestGenerateSecureToken(t *testing.T) {
	token1 := generateSecureToken(32)
	token2 := generateSecureToken(32)

	// Tokens should be different (statistically impossible to be same)
	if token1 == token2 {
		t.Error("Generated tokens should be unique")
	}

	// Token should be hex encoded (2 chars per byte)
	if len(token1) != 64 {
		t.Errorf("Expected 64 char token, got %d", len(token1))
	}

	// Different sizes
	shortToken := generateSecureToken(16)
	if len(shortToken) != 32 {
		t.Errorf("Expected 32 char token for 16 bytes, got %d", len(shortToken))
	}
}
