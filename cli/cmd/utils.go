package cmd

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"strings"
	"time"
)

// generateSecureToken creates a cryptographically secure random token
func generateSecureToken(bytes int) string {
	b := make([]byte, bytes)
	if _, err := rand.Read(b); err != nil {
		// Fallback to less secure but functional
		return "fallback_token_please_regenerate"
	}
	return hex.EncodeToString(b)
}

// containsString checks if a string slice contains a specific string
func containsString(slice []string, s string) bool {
	for _, item := range slice {
		if item == s {
			return true
		}
	}
	return false
}

// containsSubstring checks if a string contains a substring (case-sensitive)
func containsSubstring(s, substr string) bool {
	return strings.Contains(s, substr)
}

// isPortInUse checks if a port is currently in use
func isPortInUse(port string) bool {
	address := fmt.Sprintf("127.0.0.1:%s", port)
	conn, err := net.DialTimeout("tcp", address, 500*time.Millisecond)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// checkPortAvailability checks if a port is available and returns a warning message if not
func checkPortAvailability(port, service string) (available bool, message string) {
	if isPortInUse(port) {
		return false, fmt.Sprintf("Port %s is already in use (needed for %s)", port, service)
	}
	return true, ""
}

// suggestAlternativePort finds an available port starting from the given port
func suggestAlternativePort(startPort int) string {
	for port := startPort; port < startPort+100; port++ {
		if !isPortInUse(fmt.Sprintf("%d", port)) {
			return fmt.Sprintf("%d", port)
		}
	}
	return fmt.Sprintf("%d", startPort+100)
}
