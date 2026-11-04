# Steam protocol implementation

The CM, authentication and content message numbers/field layouts follow Valve's
publicly observable protocol descriptions maintained in:

- https://github.com/SteamDatabase/Protobufs/tree/master/steam
- `steammessages_base.proto`, `steammessages_clientserver_login.proto`,
  `steammessages_clientserver_appinfo.proto`, `steammessages_clientserver_2.proto`,
  `steammessages_auth.steamclient.proto`, `steammessages_contentsystem.steamclient.proto`
  and `content_manifest.proto`.

Interoperability and manifest serialization/filename cryptography were checked
against SteamKit2 (LGPL-2.1): https://github.com/SteamRE/SteamKit . This module is
implemented in Dart. It does not bundle SteamKit assemblies or a .NET runtime.

Local behavior reference: Fluent-Steam-Lua, zlib license, copyright 2024
SteamLuaManager. The application includes its original license and alteration
notice with the combined source distribution.

Supported manifest representation is modern protobuf v5 (including CDN ZIP).
Valve manifest signatures are not authenticated by this exporter. Saved manifests
carry an empty signature section like SteamKit's `SaveToFile` representation.

`bin/steam_protocol_probe.dart --live` is an explicit, read-only anonymous-network
probe. Fixture tests do not establish real-account authentication, authorization,
depot-key access, or cloud/CDN account workflows. Those require a designated
test account and legitimately accessible content.
