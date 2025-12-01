package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"
)

var dbCmd = &cobra.Command{
	Use:   "db",
	Short: "Database management commands",
	Long: `Manage the Vulcan database.

Commands:
  vulcan db migrate     # Run pending migrations
  vulcan db rollback    # Rollback last migration
  vulcan db seed        # Seed the database
  vulcan db reset       # Reset database (drop, create, migrate, seed)
  vulcan db create      # Create the database
  vulcan db drop        # Drop the database
  vulcan db status      # Show migration status
  vulcan db console     # Open database console (psql)`,
}

var dbResetCmd = &cobra.Command{
	Use:   "reset",
	Short: "Reset database (drop, create, migrate, seed)",
	Run:   runDbReset,
}

var dbMigrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Run pending migrations",
	Run:   runDbMigrate,
}

var dbRollbackCmd = &cobra.Command{
	Use:   "rollback",
	Short: "Rollback last migration (use --step=N for multiple)",
	Run:   runDbRollback,
}

var dbSeedCmd = &cobra.Command{
	Use:   "seed",
	Short: "Seed the database",
	Run:   runDbSeed,
}

var dbCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create the database",
	Run:   runDbCreate,
}

var dbDropCmd = &cobra.Command{
	Use:   "drop",
	Short: "Drop the database",
	Run:   runDbDrop,
}

var dbStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show migration status",
	Run:   runDbStatus,
}

var dbConsoleCmd = &cobra.Command{
	Use:   "console",
	Short: "Open database console (psql)",
	Run:   runDbConsole,
}

var (
	rollbackSteps int
	backupOutput  string
	restoreFile   string
)

var dbBackupCmd = &cobra.Command{
	Use:   "backup",
	Short: "Backup database to file",
	Long: `Create a PostgreSQL dump of the Vulcan database.

Examples:
  vulcan db backup                      # Backup to timestamped file
  vulcan db backup -o mybackup.sql      # Backup to specific file
  vulcan db backup -o - | gzip > backup.sql.gz  # Stream to stdout`,
	Run: runDbBackup,
}

var dbRestoreCmd = &cobra.Command{
	Use:   "restore [file]",
	Short: "Restore database from backup",
	Long: `Restore the Vulcan database from a PostgreSQL dump.

Examples:
  vulcan db restore backup.sql
  vulcan db restore -f backup.sql
  gunzip -c backup.sql.gz | vulcan db restore -f -  # Restore from stdin`,
	Run: runDbRestore,
}

var dbSnapshotCmd = &cobra.Command{
	Use:   "snapshot [name]",
	Short: "Create a named snapshot (quick backup)",
	Long: `Create a named snapshot of the current database state.
Snapshots are stored locally for quick restore during development.

Examples:
  vulcan db snapshot                    # Auto-named snapshot
  vulcan db snapshot before-migration   # Named snapshot
  vulcan db snapshot --list             # List snapshots
  vulcan db snapshot --restore latest   # Restore latest`,
	Run: runDbSnapshot,
}

var (
	snapshotList    bool
	snapshotRestore string
)

func init() {
	rootCmd.AddCommand(dbCmd)
	dbCmd.AddCommand(dbResetCmd)
	dbCmd.AddCommand(dbMigrateCmd)
	dbCmd.AddCommand(dbRollbackCmd)
	dbCmd.AddCommand(dbSeedCmd)
	dbCmd.AddCommand(dbCreateCmd)
	dbCmd.AddCommand(dbDropCmd)
	dbCmd.AddCommand(dbStatusCmd)
	dbCmd.AddCommand(dbConsoleCmd)
	dbCmd.AddCommand(dbBackupCmd)
	dbCmd.AddCommand(dbRestoreCmd)
	dbCmd.AddCommand(dbSnapshotCmd)

	dbRollbackCmd.Flags().IntVarP(&rollbackSteps, "step", "s", 1, "Number of migrations to rollback")
	dbBackupCmd.Flags().StringVarP(&backupOutput, "output", "o", "", "Output file (default: timestamped)")
	dbRestoreCmd.Flags().StringVarP(&restoreFile, "file", "f", "", "Backup file to restore")
	dbSnapshotCmd.Flags().BoolVar(&snapshotList, "list", false, "List available snapshots")
	dbSnapshotCmd.Flags().StringVar(&snapshotRestore, "restore", "", "Restore a snapshot by name")
}

// runRailsDbCommand runs a Rails db: command with proper bundle exec handling
func runRailsDbCommand(projectRoot, task string, extraArgs ...string) error {
	env := detectEnvironment(projectRoot)

	if env == "production" {
		// Production: run in Docker
		args := append([]string{"compose", "exec", "web", "bin/rails", task}, extraArgs...)
		dockerCmd := exec.Command("docker", args...)
		dockerCmd.Dir = projectRoot
		dockerCmd.Stdout = os.Stdout
		dockerCmd.Stderr = os.Stderr
		return dockerCmd.Run()
	}

	// Development: use bundle exec
	railsCmd, railsArgs := getRailsCommand(projectRoot)
	args := append(railsArgs, task)
	args = append(args, extraArgs...)

	cmd := exec.Command(railsCmd, args...)
	cmd.Dir = projectRoot
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runDbReset(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	var confirm bool
	huh.NewConfirm().
		Title("Reset database?").
		Description("This will delete all data and recreate the database").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	printInfo("Resetting database...")

	if err := runRailsDbCommand(projectRoot, "db:reset"); err != nil {
		printError("Failed to reset database")
		os.Exit(1)
	}

	printSuccess("Database reset complete")
}

func runDbMigrate(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	printInfo("Running migrations...")

	if err := runRailsDbCommand(projectRoot, "db:migrate"); err != nil {
		printError("Failed to run migrations")
		os.Exit(1)
	}

	printSuccess("Migrations complete")
}

func runDbRollback(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	var confirm bool
	huh.NewConfirm().
		Title(fmt.Sprintf("Rollback %d migration(s)?", rollbackSteps)).
		Description("This will undo recent database changes").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	printInfo(fmt.Sprintf("Rolling back %d migration(s)...", rollbackSteps))

	stepArg := fmt.Sprintf("STEP=%d", rollbackSteps)
	if err := runRailsDbCommand(projectRoot, "db:rollback", stepArg); err != nil {
		printError("Failed to rollback migrations")
		os.Exit(1)
	}

	printSuccess("Rollback complete")
}

func runDbSeed(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	printInfo("Seeding database...")

	if err := runRailsDbCommand(projectRoot, "db:seed"); err != nil {
		printError("Failed to seed database")
		os.Exit(1)
	}

	printSuccess("Seeding complete")
}

func runDbCreate(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	printInfo("Creating database...")

	if err := runRailsDbCommand(projectRoot, "db:create"); err != nil {
		printError("Failed to create database")
		os.Exit(1)
	}

	printSuccess("Database created")
}

func runDbDrop(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	var confirm bool
	huh.NewConfirm().
		Title("Drop database?").
		Description("WARNING: This will permanently delete all data!").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	printInfo("Dropping database...")

	if err := runRailsDbCommand(projectRoot, "db:drop"); err != nil {
		printError("Failed to drop database")
		os.Exit(1)
	}

	printSuccess("Database dropped")
}

func runDbStatus(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	printInfo("Migration status:")
	fmt.Println()

	if err := runRailsDbCommand(projectRoot, "db:migrate:status"); err != nil {
		printError("Failed to get migration status")
		os.Exit(1)
	}
}

func runDbConsole(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	env := detectEnvironment(projectRoot)
	if env == "production" {
		dockerCmd := exec.Command("docker", "compose", "exec", "db", "psql", "-U", "postgres")
		dockerCmd.Dir = projectRoot
		dockerCmd.Stdout = os.Stdout
		dockerCmd.Stderr = os.Stderr
		dockerCmd.Stdin = os.Stdin
		dockerCmd.Run()
	} else {
		// Try to connect to local postgres first, then docker
		// Use rails dbconsole which reads database.yml
		railsCmd, railsArgs := getRailsCommand(projectRoot)
		args := append(railsArgs, "dbconsole")

		cmd := exec.Command(railsCmd, args...)
		cmd.Dir = projectRoot
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		cmd.Run()
	}
}

func runDbBackup(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	// Determine output file
	outputFile := backupOutput
	if outputFile == "" {
		timestamp := time.Now().Format("2006-01-02_150405")
		outputFile = fmt.Sprintf("vulcan_backup_%s.sql", timestamp)
	}

	printTitle("Database Backup")
	fmt.Println()

	env := detectEnvironment(projectRoot)

	var pgDumpCmd *exec.Cmd
	if env == "production" {
		// Production: run pg_dump in docker
		pgDumpCmd = exec.Command("docker", "compose", "exec", "-T", "db",
			"pg_dump", "-U", "postgres", "-d", "vulcan_postgres_production", "--clean", "--if-exists")
	} else {
		// Development: use pg_dump directly or via docker
		pgDumpCmd = exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "exec", "-T", "db",
			"pg_dump", "-U", "postgres", "-d", "vulcan_vue_development", "--clean", "--if-exists")
	}
	pgDumpCmd.Dir = projectRoot

	if outputFile == "-" {
		// Stream to stdout
		pgDumpCmd.Stdout = os.Stdout
		pgDumpCmd.Stderr = os.Stderr
		if err := pgDumpCmd.Run(); err != nil {
			printError("Backup failed: " + err.Error())
			os.Exit(1)
		}
	} else {
		// Write to file
		printInfo("Backing up to: " + outputFile)
		output, err := pgDumpCmd.Output()
		if err != nil {
			printError("Backup failed: " + err.Error())
			os.Exit(1)
		}

		if err := os.WriteFile(outputFile, output, 0600); err != nil {
			printError("Failed to write backup: " + err.Error())
			os.Exit(1)
		}

		// Get file size
		info, _ := os.Stat(outputFile)
		size := float64(info.Size()) / 1024 / 1024
		printSuccess(fmt.Sprintf("Backup complete: %s (%.2f MB)", outputFile, size))
	}
}

func runDbRestore(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()

	// Determine input file
	inputFile := restoreFile
	if inputFile == "" && len(args) > 0 {
		inputFile = args[0]
	}

	if inputFile == "" {
		printError("Please specify a backup file to restore")
		printInfo("Usage: vulcan db restore backup.sql")
		os.Exit(1)
	}

	printTitle("Database Restore")
	fmt.Println()

	// Confirm
	var confirm bool
	huh.NewConfirm().
		Title("Restore database from " + inputFile + "?").
		Description("WARNING: This will overwrite all current data!").
		Value(&confirm).
		Run()

	if !confirm {
		printInfo("Cancelled")
		return
	}

	env := detectEnvironment(projectRoot)

	var psqlCmd *exec.Cmd
	if env == "production" {
		psqlCmd = exec.Command("docker", "compose", "exec", "-T", "db",
			"psql", "-U", "postgres", "-d", "vulcan_postgres_production")
	} else {
		psqlCmd = exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "exec", "-T", "db",
			"psql", "-U", "postgres", "-d", "vulcan_vue_development")
	}
	psqlCmd.Dir = projectRoot

	if inputFile == "-" {
		// Read from stdin
		psqlCmd.Stdin = os.Stdin
	} else {
		// Read from file
		data, err := os.ReadFile(inputFile)
		if err != nil {
			printError("Failed to read backup file: " + err.Error())
			os.Exit(1)
		}
		psqlCmd.Stdin = strings.NewReader(string(data))
	}

	psqlCmd.Stdout = os.Stdout
	psqlCmd.Stderr = os.Stderr

	printInfo("Restoring database...")
	if err := psqlCmd.Run(); err != nil {
		printError("Restore failed: " + err.Error())
		os.Exit(1)
	}

	printSuccess("Database restored successfully")
}

func runDbSnapshot(cmd *cobra.Command, args []string) {
	projectRoot := GetProjectRoot()
	snapshotDir := filepath.Join(projectRoot, ".vulcan", "snapshots")

	// Ensure snapshot directory exists
	os.MkdirAll(snapshotDir, 0700)

	// List snapshots
	if snapshotList {
		printTitle("Database Snapshots")
		fmt.Println()

		entries, err := os.ReadDir(snapshotDir)
		if err != nil || len(entries) == 0 {
			printInfo("No snapshots found")
			printInfo("Create one with: vulcan db snapshot [name]")
			return
		}

		for _, entry := range entries {
			if strings.HasSuffix(entry.Name(), ".sql") {
				info, _ := entry.Info()
				name := strings.TrimSuffix(entry.Name(), ".sql")
				size := float64(info.Size()) / 1024 / 1024
				fmt.Printf("  %s %s (%.2f MB) - %s\n",
					successStyle.Render("●"),
					name,
					size,
					info.ModTime().Format("2006-01-02 15:04:05"))
			}
		}
		return
	}

	// Restore snapshot
	if snapshotRestore != "" {
		snapshotFile := filepath.Join(snapshotDir, snapshotRestore+".sql")

		// Handle "latest"
		if snapshotRestore == "latest" {
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
				printError("No snapshots found")
				return
			}
			snapshotFile = filepath.Join(snapshotDir, latest.Name())
			snapshotRestore = strings.TrimSuffix(latest.Name(), ".sql")
		}

		if _, err := os.Stat(snapshotFile); os.IsNotExist(err) {
			printError("Snapshot not found: " + snapshotRestore)
			printInfo("Use --list to see available snapshots")
			return
		}

		restoreFile = snapshotFile
		runDbRestore(cmd, nil)
		return
	}

	// Create snapshot
	name := "snapshot"
	if len(args) > 0 {
		name = args[0]
	} else {
		name = time.Now().Format("2006-01-02_150405")
	}

	snapshotFile := filepath.Join(snapshotDir, name+".sql")
	backupOutput = snapshotFile

	printTitle("Creating Snapshot: " + name)
	fmt.Println()

	// Use the backup function
	env := detectEnvironment(projectRoot)
	var pgDumpCmd *exec.Cmd
	if env == "production" {
		pgDumpCmd = exec.Command("docker", "compose", "exec", "-T", "db",
			"pg_dump", "-U", "postgres", "-d", "vulcan_postgres_production", "--clean", "--if-exists")
	} else {
		pgDumpCmd = exec.Command("docker", "compose", "-f", "docker-compose.dev.yml", "exec", "-T", "db",
			"pg_dump", "-U", "postgres", "-d", "vulcan_vue_development", "--clean", "--if-exists")
	}
	pgDumpCmd.Dir = projectRoot

	output, err := pgDumpCmd.Output()
	if err != nil {
		printError("Snapshot failed: " + err.Error())
		os.Exit(1)
	}

	if err := os.WriteFile(snapshotFile, output, 0600); err != nil {
		printError("Failed to write snapshot: " + err.Error())
		os.Exit(1)
	}

	info, _ := os.Stat(snapshotFile)
	size := float64(info.Size()) / 1024 / 1024
	printSuccess(fmt.Sprintf("Snapshot created: %s (%.2f MB)", name, size))
	printInfo("Restore with: vulcan db snapshot --restore " + name)
}
