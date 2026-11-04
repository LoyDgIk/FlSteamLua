# Steam bridge

Windows x64 C ABI bridge used only inside the per-AppID Dart worker process.
Business logic, schema parsing, pending changes and timeouts belong to Dart.
There is no .NET runtime dependency and no redistributable Steam SDK binary.
`steamclient64.dll` is loaded from the user's selected Steam installation.

Build with CMake and the Visual Studio 2022 x64 toolchain:

```powershell
cmake -S native/steam_bridge -B native/steam_bridge/build -A x64
cmake --build native/steam_bridge/build --config Release
```

Copy `build/Release/steam_bridge.dll` next to `steam_worker.exe`. The complete ABI
is in `steam_bridge.h`. All methods run on the worker's thread. The session
must be closed before worker exit. Never switch AppID in one OS process.

`sb_open` returns null and `sb_error(nullptr)` explains connection failure.
Call `sb_request_stats`, then poll `sb_pump` / `sb_stats_ready`: 0 pending,
1 ready, -1 error. `sb_store_stats` only enqueues the request; poll
`sb_pump` / `sb_store_result` before reporting success. Dart owns timeout and
cancellation. The two ticket methods similarly separate request and polling.

This is an altered C++ port of Steam client interface knowledge from the local
Fluent-Steam-Lua project and SAM.API, not an original SAM distribution. Preserve
the original zlib notices in `LICENSES`. Steam's private client interfaces can
change independently; integration must be verified against the actual client.
