# LAN transfer engine

Standalone Windows x64 Go process for FlSteamLua LAN transfers. Flutter starts
it with `--data-dir <directory>` and controls it through newline-delimited
JSON-RPC on stdin/stdout. Engine logs use stderr.

The engine owns device discovery, mutual TLS identity, transfer plans, chunk
scheduling, staging, resumable state, and installation. It does not implement
Steam's private LAN transfer protocol.

Build and test:

```powershell
go test ./...
go build -trimpath -ldflags "-s -w -H=windowsgui" `
  -o ..\..\build\windows\x64\runner\Release\lan_transfer_engine.exe `
  .\cmd\lan_transfer_engine
```

The release script performs the same build and packages the executable beside
`fl_steam_lua.exe`.
