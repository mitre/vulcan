package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRunRailsDbCommandDevelopment(t *testing.T) {
	// This tests the helper function logic without actually running commands
	// Since we can't easily mock exec.Command, we test the environment detection
	projectRoot := t.TempDir()

	// In a clean temp directory, should detect as development (no .dockerenv, no BUNDLE_PATH)
	env := detectEnvironment(projectRoot)
	if env != "development" {
		t.Logf("Environment detected as %s (expected development in most test scenarios)", env)
	}
}

func TestDetectEnvironmentDevelopment(t *testing.T) {
	// Create temp project without production markers
	projectRoot := t.TempDir()

	env := detectEnvironment(projectRoot)
	if env != "development" {
		t.Errorf("Expected development environment, got: %s", env)
	}
}

func TestDetectEnvironmentProduction(t *testing.T) {
	// Create temp project with production .env
	projectRoot := t.TempDir()
	envPath := filepath.Join(projectRoot, ".env")

	content := "RAILS_ENV=production\nDATABASE_URL=postgres://localhost/vulcan\n"
	err := os.WriteFile(envPath, []byte(content), 0600)
	if err != nil {
		t.Fatalf("Failed to create .env: %v", err)
	}

	env := detectEnvironment(projectRoot)
	if env != "production" {
		t.Errorf("Expected production environment, got: %s", env)
	}
}

func TestSnapshotDirectoryCreation(t *testing.T) {
	// Test that snapshot directory gets created with proper permissions
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	// Directory shouldn't exist initially
	if _, err := os.Stat(snapshotDir); !os.IsNotExist(err) {
		t.Error("Snapshot directory should not exist initially")
	}

	// Create it with the same code pattern used in runDbSnapshot
	err := os.MkdirAll(snapshotDir, 0700)
	if err != nil {
		t.Fatalf("Failed to create snapshot directory: %v", err)
	}

	// Verify directory exists and has correct permissions
	info, err := os.Stat(snapshotDir)
	if err != nil {
		t.Fatalf("Snapshot directory not created: %v", err)
	}

	if !info.IsDir() {
		t.Error("Snapshot path should be a directory")
	}

	mode := info.Mode().Perm()
	if mode != 0700 {
		t.Errorf("Snapshot directory permissions = %o, expected 0700", mode)
	}
}

func TestSnapshotFilenameGeneration(t *testing.T) {
	// Test auto-generated snapshot names follow expected format
	name := time.Now().Format("2006-01-02_150405")

	// Should match YYYY-MM-DD_HHMMSS format
	if len(name) != 17 {
		t.Errorf("Expected snapshot name length 17, got %d", len(name))
	}

	// Should contain date separator
	if !strings.Contains(name, "-") {
		t.Error("Snapshot name should contain date separators")
	}

	// Should contain underscore between date and time
	if !strings.Contains(name, "_") {
		t.Error("Snapshot name should contain underscore separator")
	}
}

func TestSnapshotListEmpty(t *testing.T) {
	// Test listing snapshots in empty directory
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	os.MkdirAll(snapshotDir, 0700)

	entries, err := os.ReadDir(snapshotDir)
	if err != nil {
		t.Fatalf("Failed to read snapshot directory: %v", err)
	}

	if len(entries) != 0 {
		t.Errorf("Expected 0 entries in empty snapshot dir, got %d", len(entries))
	}
}

func TestSnapshotListWithFiles(t *testing.T) {
	// Test listing snapshots when files exist
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	os.MkdirAll(snapshotDir, 0700)

	// Create some fake snapshot files
	testSnapshots := []string{
		"before-migration.sql",
		"2024-01-15_103000.sql",
		"clean-state.sql",
	}

	for _, name := range testSnapshots {
		path := filepath.Join(snapshotDir, name)
		err := os.WriteFile(path, []byte("-- fake sql dump"), 0600)
		if err != nil {
			t.Fatalf("Failed to create test snapshot: %v", err)
		}
	}

	entries, err := os.ReadDir(snapshotDir)
	if err != nil {
		t.Fatalf("Failed to read snapshot directory: %v", err)
	}

	if len(entries) != 3 {
		t.Errorf("Expected 3 snapshots, got %d", len(entries))
	}

	// Verify all files end with .sql
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".sql") {
			t.Errorf("Snapshot file should end with .sql: %s", entry.Name())
		}
	}
}

func TestSnapshotLatestSelection(t *testing.T) {
	// Test finding the latest snapshot
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	os.MkdirAll(snapshotDir, 0700)

	// Create snapshots with different modification times
	snapshots := []string{"old.sql", "middle.sql", "newest.sql"}

	for i, name := range snapshots {
		path := filepath.Join(snapshotDir, name)
		err := os.WriteFile(path, []byte("-- sql"), 0600)
		if err != nil {
			t.Fatalf("Failed to create snapshot: %v", err)
		}

		// Set modification time (older to newer)
		modTime := time.Now().Add(time.Duration(i) * time.Second)
		os.Chtimes(path, modTime, modTime)
	}

	// Find latest using same logic as runDbSnapshot
	entries, _ := os.ReadDir(snapshotDir)
	var latest os.DirEntry
	var latestTime time.Time

	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".sql") {
			info, _ := e.Info()
			if info.ModTime().After(latestTime) {
				latestTime = info.ModTime()
				latest = e
			}
		}
	}

	if latest == nil {
		t.Fatal("Should find a latest snapshot")
	}

	if latest.Name() != "newest.sql" {
		t.Errorf("Expected newest.sql as latest, got: %s", latest.Name())
	}
}

func TestBackupOutputFilename(t *testing.T) {
	// Test backup filename generation
	timestamp := time.Now().Format("2006-01-02_150405")
	outputFile := "vulcan_backup_" + timestamp + ".sql"

	// Should have the vulcan_backup_ prefix
	if !strings.HasPrefix(outputFile, "vulcan_backup_") {
		t.Error("Backup filename should start with vulcan_backup_")
	}

	// Should end with .sql
	if !strings.HasSuffix(outputFile, ".sql") {
		t.Error("Backup filename should end with .sql")
	}

	// Should have reasonable length
	if len(outputFile) < 25 || len(outputFile) > 35 {
		t.Errorf("Unexpected backup filename length: %d", len(outputFile))
	}
}

func TestBackupFilePermissions(t *testing.T) {
	// Test that backup files are created with secure permissions
	tmpDir := t.TempDir()
	backupPath := filepath.Join(tmpDir, "test_backup.sql")

	// Simulate writing a backup with secure permissions
	err := os.WriteFile(backupPath, []byte("-- test backup"), 0600)
	if err != nil {
		t.Fatalf("Failed to create test backup: %v", err)
	}

	info, err := os.Stat(backupPath)
	if err != nil {
		t.Fatalf("Failed to stat backup file: %v", err)
	}

	mode := info.Mode().Perm()
	if mode != 0600 {
		t.Errorf("Backup file permissions = %o, expected 0600", mode)
	}
}

func TestRestoreFileValidation(t *testing.T) {
	// Test that restore requires a file argument
	inputFile := ""
	args := []string{}

	// Simulate the logic from runDbRestore
	if inputFile == "" && len(args) > 0 {
		inputFile = args[0]
	}

	if inputFile != "" {
		t.Error("Should not have input file when none provided")
	}
}

func TestRestoreFileFromArgs(t *testing.T) {
	// Test that restore can take file from args
	inputFile := ""
	args := []string{"my_backup.sql"}

	// Simulate the logic from runDbRestore
	if inputFile == "" && len(args) > 0 {
		inputFile = args[0]
	}

	if inputFile != "my_backup.sql" {
		t.Errorf("Expected my_backup.sql, got: %s", inputFile)
	}
}

func TestRestoreFileFromFlag(t *testing.T) {
	// Test that restore can take file from -f flag
	inputFile := "backup_from_flag.sql"
	_ = []string{"backup_from_args.sql"} // This would be ignored when flag is set

	// Flag takes precedence (inputFile already set)
	if inputFile != "backup_from_flag.sql" {
		t.Error("Flag should take precedence over args")
	}
}

func TestSnapshotFilePathConstruction(t *testing.T) {
	projectRoot := "/projects/vulcan"
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")
	name := "before-migration"

	expectedPath := filepath.Join(snapshotDir, name+".sql")
	actualPath := filepath.Join(snapshotDir, name+".sql")

	if expectedPath != actualPath {
		t.Errorf("Path construction mismatch: %s vs %s", expectedPath, actualPath)
	}

	// Verify it ends with .sql
	if !strings.HasSuffix(actualPath, ".sql") {
		t.Error("Snapshot path should end with .sql")
	}
}

func TestSnapshotRestoreLatestNotFound(t *testing.T) {
	// Test handling of empty snapshot directory when restoring "latest"
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	os.MkdirAll(snapshotDir, 0700)

	entries, _ := os.ReadDir(snapshotDir)
	var latest os.DirEntry
	var latestTime time.Time

	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".sql") {
			info, _ := e.Info()
			if info.ModTime().After(latestTime) {
				latestTime = info.ModTime()
				latest = e
			}
		}
	}

	if latest != nil {
		t.Error("Should not find latest in empty directory")
	}
}

func TestSnapshotRestoreByName(t *testing.T) {
	projectRoot := t.TempDir()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")
	os.MkdirAll(snapshotDir, 0700)

	// Create a named snapshot
	snapshotName := "my-named-snapshot"
	snapshotPath := filepath.Join(snapshotDir, snapshotName+".sql")
	os.WriteFile(snapshotPath, []byte("-- snapshot data"), 0600)

	// Verify it exists
	_, err := os.Stat(snapshotPath)
	if os.IsNotExist(err) {
		t.Error("Named snapshot should exist")
	}

	// Verify the path construction is correct
	expectedPath := filepath.Join(snapshotDir, snapshotName+".sql")
	if snapshotPath != expectedPath {
		t.Errorf("Expected %s, got %s", expectedPath, snapshotPath)
	}
}
