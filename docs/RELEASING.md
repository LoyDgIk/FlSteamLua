# Releasing

## Version contract

`pubspec.yaml`, `CHANGELOG.md` and the annotated Git tag must use the same
version:

- `pubspec.yaml`: `version: 0.2.0+2`
- `CHANGELOG.md`: `## [0.2.0] - YYYY-MM-DD`
- Git tag: `v0.2.0`

The build passes `APP_VERSION` into Flutter. The client update source is fixed
to `LoyDgIk/FlSteamLua`; no user-configured repository is supported.

## Local verification

```powershell
./scripts/get-release-notes.ps1 -Version 0.2.0
./scripts/build-release.ps1
```

`dist` receives the installer, portable ZIP, corresponding source ZIP and
SHA-256 sidecars.

Release builds run the high-signal file list in `scripts/release-tests.txt`
instead of the complete UI-heavy suite. Presentation-only tests are kept out of
the release path; run `./scripts/build-release.ps1 -FullTests` when a complete
local regression run is required.

## Tag and publish

Commit the version and changelog changes first, then run:

```powershell
./scripts/tag-release.ps1 -Version 0.2.0
```

The script refuses a dirty tree, a mismatched version, an existing tag or a
missing changelog section. It creates the annotated tag and pushes it to
`origin`.

Pushing a `v*` tag starts `.github/workflows/release.yml`. The workflow:

1. Builds and tests the Windows application, Dart workers, Go engine and native
   bridge.
2. Builds installer, portable ZIP and source ZIP artifacts.
3. Extracts release notes from `CHANGELOG.md`.
4. Publishes all artifacts and checksum sidecars to the matching GitHub Release.

The client update check reads the latest stable GitHub Release. Downloads prefer
the x64 setup executable, then the portable x64 ZIP, and require a SHA-256 digest
from the GitHub asset metadata or the matching `.sha256` asset.
