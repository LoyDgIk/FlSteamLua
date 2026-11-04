# Windows release

Run `pwsh -File scripts/build-release.ps1` from a Windows development machine
with Flutter, the Visual Studio C++ desktop tools and Inno Setup 6 installed.
The script performs analysis and tests, builds the Flutter release, compiles the
Dart Steam worker and native Steam bridge, and emits a ZIP, installer and SHA256
files under `dist`. `-SkipChecks` only reuses checks already run on the same tree.

The installation is per-user and does not require administrator privileges. The
installer and binaries are unsigned unless the distributor adds a real signing
step using their own certificate. Neither the installer nor the build script
enables Steam modifications or configures startup registration.

Updates must use this application's own GitHub release repository. It is left
unconfigured until a distributor supplies `owner/repository` in Settings; the
WPF upstream's executables are not updates for this application.
