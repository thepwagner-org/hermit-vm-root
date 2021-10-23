package main

import (
	"os"

	"github.com/go-logr/logr"
	"github.com/go-logr/zerologr"
	"github.com/rs/zerolog"
)

func NewLogger() logr.Logger {
	zl := zerolog.New(os.Stderr)
	return zerologr.New(&zl)
}
