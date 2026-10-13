package main

import (
	"context"
	"os"
	"os/signal"
	"runtime/debug"
	"syscall"

	"github.com/peak/s5cmd/v2/command"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	debug.SetMaxThreads(75000)
	go func() {
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
		<-ch
		cancel()
		signal.Stop(ch)
	}()

	if err := command.Main(ctx, os.Args); err != nil {
		os.Exit(1)
	}
}
