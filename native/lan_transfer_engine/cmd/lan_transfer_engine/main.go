package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"flsteamlua/lan_transfer_engine/internal/engine"
	"flsteamlua/lan_transfer_engine/internal/instance"
	"flsteamlua/lan_transfer_engine/internal/ipc"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

func main() {
	dataDir := flag.String("data-dir", "", "engine data directory")
	flag.Parse()
	if *dataDir == "" {
		fmt.Fprintln(os.Stderr, "lan_transfer_engine: --data-dir is required")
		os.Exit(2)
	}
	log.SetOutput(os.Stderr)
	lock, err := instance.Acquire(*dataDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "lan_transfer_engine:", err)
		os.Exit(1)
	}
	defer lock.Close()
	instance, err := engine.New(*dataDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "lan_transfer_engine:", err)
		os.Exit(1)
	}
	instance.Emit("ready", map[string]any{
		"engineProtocol": "flsteamlua-engine/1",
		"lanProtocol":    protocol.LANProtocol,
		"version":        "0.1.0",
	})
	if err := ipc.New(instance, os.Stdout).Run(); err != nil {
		fmt.Fprintln(os.Stderr, "lan_transfer_engine:", err)
		os.Exit(1)
	}
}
