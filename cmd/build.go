package main

import (
	"os"

	"github.com/spf13/cobra"
)

// buildCmd executes the build inside the guest sandbox.
var buildCmd = &cobra.Command{
	Use: "build",
	RunE: func(cmd *cobra.Command, args []string) error {
		ctx := cmd.Context()
		log := NewLogger()
		b, err := NewBuilder(ctx, log, "/output")
		if err != nil {
			return err
		}

		wd, err := os.Getwd()
		if err != nil {
			return err
		}
		return b.Build(ctx, wd)
	},
}

func init() {
	guestCmd.AddCommand(buildCmd)
}
