# Steam client history catalogue

The 59 build/snapshot pairs are factual metadata from the user-provided
SteamVault 1.0.0 catalogue (`D:/tool/steam update`), checked against Wayback CDX
and manifest responses on 2026-11-06 where reachable. No application code,
translated release notes or executables are copied. Some snapshots were not
reachable during the check; directory membership does not promise that all
historical packages are available.

Two reference entries were omitted because Wayback replay returned a different
build (1745876290 and 1766177208). The expected-build check prevents a different
client from being downloaded as the selected version.

The seed provides offline version choices. The application refreshes official
latest releases and the configured Wayback CDX index to discover newer entries.
Package manifests are loaded for a selected entry and must match the expected
architecture/build before downloads and installation can proceed.
