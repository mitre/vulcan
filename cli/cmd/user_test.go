package cmd

import (
	"strings"
	"testing"
)

func TestValidatePasswordStrength(t *testing.T) {
	tests := []struct {
		password string
		valid    bool
		errMsg   string
	}{
		// Valid passwords
		{"SecurePass123!", true, ""},
		{"MyP@ssw0rd!abc", true, ""},
		{"Abc123!@#defGHI", true, ""},

		// Too short
		{"Short1!", false, "at least 12 characters"},

		// Missing uppercase
		{"lowercase123!", false, "uppercase letter"},

		// Missing lowercase
		{"UPPERCASE123!", false, "lowercase letter"},

		// Missing digit
		{"SecurePass!!!", false, "digit"},

		// Missing special character
		{"SecurePass1234", false, "special character"},
	}

	for _, tt := range tests {
		t.Run(tt.password, func(t *testing.T) {
			err := validatePasswordStrength(tt.password)

			if tt.valid && err != nil {
				t.Errorf("Expected password '%s' to be valid, got error: %v", tt.password, err)
			}

			if !tt.valid {
				if err == nil {
					t.Errorf("Expected password '%s' to be invalid, but it passed", tt.password)
				} else if tt.errMsg != "" && !strings.Contains(err.Error(), tt.errMsg) {
					t.Errorf("Expected error to contain '%s', got: %v", tt.errMsg, err)
				}
			}
		})
	}
}

func TestGenerateSecurePassword(t *testing.T) {
	// Generate multiple passwords and verify they meet requirements
	for i := 0; i < 10; i++ {
		password := generateSecurePassword(20)

		if len(password) != 20 {
			t.Errorf("Expected password length 20, got %d", len(password))
		}

		// Verify generated passwords pass validation
		if err := validatePasswordStrength(password); err != nil {
			t.Errorf("Generated password failed validation: %v (password: %s)", err, password)
		}
	}
}

func TestGenerateSecurePasswordUniqueness(t *testing.T) {
	passwords := make(map[string]bool)

	// Generate 100 passwords and ensure they're all unique
	for i := 0; i < 100; i++ {
		password := generateSecurePassword(20)
		if passwords[password] {
			t.Errorf("Duplicate password generated: %s", password)
		}
		passwords[password] = true
	}
}

func TestGenerateSecurePasswordCharacterClasses(t *testing.T) {
	// Generate many passwords and verify character distribution
	for i := 0; i < 50; i++ {
		password := generateSecurePassword(20)

		hasUpper := false
		hasLower := false
		hasDigit := false
		hasSpecial := false

		for _, c := range password {
			switch {
			case c >= 'A' && c <= 'Z':
				hasUpper = true
			case c >= 'a' && c <= 'z':
				hasLower = true
			case c >= '0' && c <= '9':
				hasDigit = true
			case strings.ContainsRune("!@#$%^&*", c):
				hasSpecial = true
			}
		}

		if !hasUpper {
			t.Errorf("Password missing uppercase: %s", password)
		}
		if !hasLower {
			t.Errorf("Password missing lowercase: %s", password)
		}
		if !hasDigit {
			t.Errorf("Password missing digit: %s", password)
		}
		if !hasSpecial {
			t.Errorf("Password missing special character: %s", password)
		}
	}
}

func TestHashForLogging(t *testing.T) {
	// Hash should be deterministic
	hash1 := hashForLogging("test123")
	hash2 := hashForLogging("test123")

	if hash1 != hash2 {
		t.Error("Hash should be deterministic for same input")
	}

	// Different inputs should produce different hashes
	hash3 := hashForLogging("different")
	if hash1 == hash3 {
		t.Error("Different inputs should produce different hashes")
	}

	// Hash should end with "..."
	if !strings.HasSuffix(hash1, "...") {
		t.Errorf("Hash should end with '...', got: %s", hash1)
	}

	// Hash should be short (safe for logging)
	if len(hash1) > 15 {
		t.Errorf("Hash should be short for logging, got length: %d", len(hash1))
	}
}

func TestGenerateRandomID(t *testing.T) {
	ids := make(map[string]bool)

	// Generate many IDs and ensure uniqueness
	for i := 0; i < 100; i++ {
		id := generateRandomID()

		if ids[id] {
			t.Errorf("Duplicate ID generated: %s", id)
		}
		ids[id] = true

		// ID should be reasonable length
		if len(id) < 8 || len(id) > 20 {
			t.Errorf("ID length should be between 8-20, got: %d", len(id))
		}
	}
}

func TestGetRailsCommand(t *testing.T) {
	// In a normal dev environment (no Docker, no BUNDLE_PATH), should use bundle exec
	// Note: This test assumes we're not running inside Docker
	cmd, args := getRailsCommand("/some/project")

	// In development, we expect bundle exec rails
	if cmd != "bundle" {
		// Could be running in Docker or with BUNDLE_PATH set
		if cmd != "bin/rails" {
			t.Errorf("Expected 'bundle' or 'bin/rails', got: %s", cmd)
		}
	} else {
		// Verify args are correct for bundle exec
		if len(args) != 2 || args[0] != "exec" || args[1] != "rails" {
			t.Errorf("Expected args ['exec', 'rails'], got: %v", args)
		}
	}
}
