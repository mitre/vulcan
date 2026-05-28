package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGetCLIVersion_ReadsCliVersionFile(t *testing.T) {
	tmpDir := t.TempDir()

	// Create cli/VERSION in a fake project root
	cliDir := filepath.Join(tmpDir, "cli")
	os.Mkdir(cliDir, 0755)
	os.WriteFile(filepath.Join(cliDir, "VERSION"), []byte("1.0.0\n"), 0644)

	version := getCLIVersion(tmpDir)
	if version != "1.0.0" {
		t.Errorf("getCLIVersion() = %q, want %q", version, "1.0.0")
	}
}

func TestGetCLIVersion_FallsBackToDev(t *testing.T) {
	tmpDir := t.TempDir()
	// No VERSION file exists

	version := getCLIVersion(tmpDir)
	if version != "dev" {
		t.Errorf("getCLIVersion() = %q, want %q", version, "dev")
	}
}

func TestGetCLIVersion_TrimsWhitespace(t *testing.T) {
	tmpDir := t.TempDir()
	cliDir := filepath.Join(tmpDir, "cli")
	os.Mkdir(cliDir, 0755)
	os.WriteFile(filepath.Join(cliDir, "VERSION"), []byte("  2.1.0  \n"), 0644)

	version := getCLIVersion(tmpDir)
	if version != "2.1.0" {
		t.Errorf("getCLIVersion() = %q, want %q", version, "2.1.0")
	}
}

func TestGetCLIVersion_EmptyFileFallsToDev(t *testing.T) {
	tmpDir := t.TempDir()
	cliDir := filepath.Join(tmpDir, "cli")
	os.Mkdir(cliDir, 0755)
	os.WriteFile(filepath.Join(cliDir, "VERSION"), []byte("  \n"), 0644)

	version := getCLIVersion(tmpDir)
	if version != "dev" {
		t.Errorf("getCLIVersion() = %q, want %q", version, "dev")
	}
}

func TestGetProjectVersion_ReadsVersionFile(t *testing.T) {
	tmpDir := t.TempDir()
	os.WriteFile(filepath.Join(tmpDir, "VERSION"), []byte("3.0.0\n"), 0644)

	version := getProjectVersion(tmpDir)
	if version != "3.0.0" {
		t.Errorf("getProjectVersion() = %q, want %q", version, "3.0.0")
	}
}

func TestGetProjectVersion_FallsBackToDev(t *testing.T) {
	tmpDir := t.TempDir()

	version := getProjectVersion(tmpDir)
	if version != "dev" {
		t.Errorf("getProjectVersion() = %q, want %q", version, "dev")
	}
}

func TestGetProjectVersion_TrimsWhitespace(t *testing.T) {
	tmpDir := t.TempDir()
	os.WriteFile(filepath.Join(tmpDir, "VERSION"), []byte("  3.0.0  \n"), 0644)

	version := getProjectVersion(tmpDir)
	if version != "3.0.0" {
		t.Errorf("getProjectVersion() = %q, want %q", version, "3.0.0")
	}
}

func TestCLIAndAppVersionsAreIndependent(t *testing.T) {
	tmpDir := t.TempDir()

	// Create both VERSION files with different values
	os.WriteFile(filepath.Join(tmpDir, "VERSION"), []byte("3.0.0\n"), 0644)
	cliDir := filepath.Join(tmpDir, "cli")
	os.Mkdir(cliDir, 0755)
	os.WriteFile(filepath.Join(cliDir, "VERSION"), []byte("1.0.0\n"), 0644)

	appVersion := getProjectVersion(tmpDir)
	cliVersion := getCLIVersion(tmpDir)

	if appVersion == cliVersion {
		t.Errorf("App and CLI versions should be independent, both are %q", appVersion)
	}
	if appVersion != "3.0.0" {
		t.Errorf("App version = %q, want %q", appVersion, "3.0.0")
	}
	if cliVersion != "1.0.0" {
		t.Errorf("CLI version = %q, want %q", cliVersion, "1.0.0")
	}
}

func TestRootCmdVersionFormat(t *testing.T) {
	// rootCmd.Version should contain both CLI and app versions
	version := rootCmd.Version
	if version == "" {
		t.Fatal("rootCmd.Version should not be empty")
	}

	// Should contain parenthesized Vulcan app version
	if !strings.Contains(version, "(Vulcan") {
		t.Errorf("rootCmd.Version = %q, should contain '(Vulcan ...)'", version)
	}
}

func TestBuildVersionDefaultReadsVersionFile(t *testing.T) {
	// readVersionFile("VERSION", "latest") searches ., .., ../.. for a VERSION file.
	// Tests run from cli/cmd/, so ../VERSION = cli/VERSION and ../../VERSION = project root VERSION.
	// The project root VERSION file contains 3.0.0, so this should NOT return "latest".
	version := readVersionFile("VERSION", "latest")
	if version == "latest" {
		t.Error("readVersionFile('VERSION') returned 'latest' — it should find the VERSION file in the search path")
	}
	if version == "" {
		t.Error("readVersionFile('VERSION') returned empty string")
	}
}

func TestReadVersionFileFallback(t *testing.T) {
	// A filename that doesn't exist anywhere should return the fallback
	version := readVersionFile("DOES_NOT_EXIST_ANYWHERE", "latest")
	if version != "latest" {
		t.Errorf("readVersionFile(missing) = %q, want %q", version, "latest")
	}
}
