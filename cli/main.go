package main

import (
	"os"

	"github.com/mitre/vulcan/cli/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
