import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../platform/windows/dpapi.dart';
import '../library/kv1.dart';
import 'app_info.dart';
import 'auth/steam_auth_client.dart';
import 'cm_client.dart';
import 'manifest/depot_manifest.dart';
import 'wire/protobuf.dart';

export 'app_info.dart';
export 'auth/steam_auth_client.dart' show SteamAuthException;
export 'cm_client.dart' show SteamProtocolException;

class SteamGuardPrompt {
  const SteamGuardPrompt(this.type, this.message);
  final int type;
  final String message;
  bool get needsCode => type == 2 || type == 3;
}

class SteamExtractionResult {
  const SteamExtractionResult({
    required this.luaFile,
    required this.keyCount,
    required this.manifests,
    required this.warnings,
  });
  final String luaFile;
  final int keyCount;
  final List<String> manifests;
  final List<String> warnings;
}

class SteamProtocolService extends ChangeNotifier {
  SteamProtocolService({
    required this.paths,
    required this.settings,
    http.Client? httpClient,
    SteamCmClient? accountClient,
    SteamCmClient? anonymousClient,
    String Function(String)? protect,
    String Function(String)? unprotect,
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _protect =
           protect ??
           ((value) => WindowsDpapi.protectString(
             value,
             entropy: 'FlSteamLua:steam-session',
           )),
       _unprotect =
           unprotect ??
           ((value) => WindowsDpapi.unprotectString(
             value,
             entropy: 'FlSteamLua:steam-session',
           )) {
    _account = accountClient ?? SteamCmClient(_http);
    _account.onStateChanged = _changed;
    _anonymous = anonymousClient ?? SteamCmClient(_http);
    _auth = SteamAuthClient(
      _http,
      transport: (method, payload) async {
        final packet = await _account.unified(
          'Authentication.$method#1',
          ProtoWriter.fromBytes(payload),
          authenticated: _account.isLoggedOn,
        );
        return SteamAuthResponse(
          packet.body,
          result: packet.header.intValue(13, defaultValue: 1),
          message: packet.header.stringValue(14),
        );
      },
    );
  }

  final AppPaths paths;
  final SettingsStore settings;
  final http.Client _http;
  final bool _ownsHttp;
  final String Function(String) _protect;
  final String Function(String) _unprotect;
  late final SteamCmClient _account;
  late final SteamCmClient _anonymous;
  late final SteamAuthClient _auth;
  String? _accountName;
  bool _authenticating = false;
  bool _disposed = false;

  bool get isLoggedOn => _account.isLoggedOn;
  bool get isAuthenticating => _authenticating;
  String? get currentAccountName => isLoggedOn ? _accountName : null;
  String? get savedAccountName {
    final name = settings.get<String>('steamAccountName', '');
    return name.isEmpty ? null : name;
  }

  bool get hasSavedSession =>
      settings.get<String>('steamSession', '').isNotEmpty;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loginWithCredentials(
    String username,
    String password, {
    required Future<String?> Function(SteamGuardPrompt) onGuard,
    TaskContext? task,
  }) async {
    if (_authenticating) {
      throw StateError('Steam authentication is already running');
    }
    _authenticating = true;
    _changed();
    try {
      if (_account.isLoggedOn) await _account.close();
      task?.report('Connecting to Steam');
      final challenge = await _auth.beginCredentials(
        username,
        password,
        guardData: _savedGuardData(username),
      );
      task?.checkCancelled();
      final codeConfirmations = challenge.allowedConfirmations
          .where((c) => c.needsCode)
          .toList();
      final approval = challenge.allowedConfirmations
          .where((c) => c.needsApproval)
          .toList();
      if (approval.isNotEmpty) {
        final type = approval.first;
        final accepted = await onGuard(
          SteamGuardPrompt(type.type, type.message),
        );
        if (accepted == null) throw const TaskCancelled();
      } else if (codeConfirmations.isNotEmpty) {
        final type = codeConfirmations.first;
        final code = await onGuard(SteamGuardPrompt(type.type, type.message));
        if (code == null) throw const TaskCancelled();
        await _auth.submitGuard(challenge, code, type.type);
      } else if (!challenge.allowedConfirmations.any((c) => c.type == 1)) {
        throw const SteamProtocolException(
          'Steam requires an unsupported authentication confirmation',
        );
      }
      task?.report('Waiting for Steam authentication');
      final tokens = await _auth.waitForTokens(
        challenge,
        isCancelled: () => task?.isCancelled ?? false,
      );
      task?.checkCancelled();
      await _account.logOn(
        accountName: tokens.accountName,
        refreshToken: tokens.refreshToken,
        userSteamId: tokens.steamId,
      );
      _accountName = tokens.accountName;
      await _saveTokens(tokens);
    } on SteamAuthException catch (error) {
      if (error.result == 52 && (task?.isCancelled ?? false)) {
        throw const TaskCancelled();
      }
      rethrow;
    } finally {
      _authenticating = false;
      _changed();
    }
  }

  String? _savedGuardData(String username) {
    if (savedAccountName?.toLowerCase() != username.toLowerCase()) return null;
    final encrypted = settings.get<String>('steamSession', '');
    if (encrypted.isEmpty) return null;
    final session = jsonDecode(_unprotect(encrypted)) as Map<String, dynamic>;
    return session['guardData'] as String?;
  }

  Future<void> restoreSession() async {
    if (isLoggedOn) return;
    final encrypted = settings.get<String>('steamSession', '');
    if (encrypted.isEmpty) {
      throw const SteamProtocolException(
        'No saved Steam session; sign in first',
      );
    }
    final session = jsonDecode(_unprotect(encrypted));
    if (session is! Map ||
        session['accountName'] is! String ||
        session['refreshToken'] is! String) {
      throw const FormatException('Invalid saved Steam session');
    }
    final username = session['accountName'] as String;
    var token = session['refreshToken'] as String;
    await _account.logOn(
      accountName: username,
      refreshToken: token,
      userSteamId: jwtSteamId(token),
    );
    _accountName = username;
    final expiry = _jwtExpiry(token);
    if (expiry != null &&
        expiry.isBefore(DateTime.now().toUtc().add(const Duration(days: 30)))) {
      final renewed = await _auth.renew(_account.steamId, token);
      token = renewed.refreshToken;
      await _saveTokens(
        SteamAuthTokens(
          accountName: username,
          accessToken: renewed.accessToken,
          refreshToken: token,
          guardData: session['guardData'] as String?,
        ),
      );
    }
    _changed();
  }

  /// Restores the current Steam client login from local.vdf.
  ///
  /// Steam stores refresh-token blobs protected with DPAPI and the account
  /// name as entropy. This never prompts for a password and does not bypass
  /// the account's own Steam login.
  Future<bool> restoreLocalSession({TaskContext? task}) async {
    if (isLoggedOn) return true;
    if (!Platform.isWindows) return false;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) return false;
    final localFile = File(p.join(localAppData, 'Steam', 'local.vdf'));
    if (!await localFile.exists()) return false;

    final Map<String, dynamic> root;
    try {
      root = Kv1.parse(await localFile.readAsString());
    } catch (_) {
      return false;
    }
    final cache = _nestedMap(root, [
      'MachineUserConfigStore',
      'Software',
      'Valve',
      'Steam',
      'ConnectCache',
    ]);
    if (cache == null || cache.isEmpty) return false;

    final accounts = await _localAccountNames();
    final saved = savedAccountName;
    if (saved != null && saved.isNotEmpty) accounts.insert(0, saved);
    for (final account in accounts.toSet()) {
      task?.checkCancelled();
      final entropy = Uint8List.fromList(utf8.encode(account));
      for (final raw in cache.values) {
        if (raw is! String) continue;
        final encrypted = _decodeHex(raw);
        if (encrypted == null || encrypted.length < 64) continue;
        List<int> clear;
        try {
          clear = WindowsDpapi.unprotectBytes(encrypted, entropy: entropy);
        } catch (_) {
          continue;
        }
        final token = utf8.decode(clear, allowMalformed: true).trim();
        if (!_looksLikeSteamToken(token)) continue;
        try {
          await _account.logOn(
            accountName: account,
            refreshToken: token,
            userSteamId: jwtSteamId(token),
          );
          _accountName = account;
          await _saveTokens(
            SteamAuthTokens(
              accountName: account,
              accessToken: token,
              refreshToken: token,
              guardData: null,
            ),
          );
          _changed();
          return true;
        } catch (_) {
          continue;
        }
      }
    }
    return false;
  }

  DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final value = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = value is Map ? value['exp'] : null;
    return exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
        : null;
  }

  Future<List<String>> _localAccountNames() async {
    final steamPath = settings.steamPath;
    if (steamPath.isEmpty) return [];
    final file = File(p.join(steamPath, 'config', 'loginusers.vdf'));
    if (!await file.exists()) return [];
    try {
      final root = Kv1.parse(await file.readAsString());
      final users = _nestedMap(root, ['users']);
      if (users == null) return [];
      return [
        for (final value in users.values)
          if (value is Map && value['AccountName'] is String)
            value['AccountName'] as String,
      ].where((value) => value.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic>? _nestedMap(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    dynamic current = root;
    for (final key in keys) {
      if (current is! Map || !current.containsKey(key)) return null;
      current = current[key];
    }
    return current is Map ? Map<String, dynamic>.from(current) : null;
  }

  static Uint8List? _decodeHex(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length.isOdd) return null;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return null;
    return Uint8List.fromList([
      for (var index = 0; index < text.length; index += 2)
        int.parse(text.substring(index, index + 2), radix: 16),
    ]);
  }

  static bool _looksLikeSteamToken(String value) {
    final parts = value.split('.');
    return parts.length == 3 && parts.first.startsWith('ey');
  }

  Future<void> _saveTokens(SteamAuthTokens tokens) async {
    final encrypted = _protect(
      jsonEncode({
        'accountName': tokens.accountName,
        'refreshToken': tokens.refreshToken,
        'guardData': tokens.guardData,
      }),
    );
    await settings.set('steamSession', encrypted);
    await settings.set('steamAccountName', tokens.accountName);
  }

  Future<void> logOff({bool forget = true}) async {
    await _account.close();
    _accountName = null;
    if (forget) {
      await settings.set('steamSession', '');
      await settings.set('steamAccountName', '');
    }
    _changed();
  }

  Future<SteamCmClient> _appInfoClient() async {
    if (_account.isLoggedOn) return _account;
    await _anonymous.logOn();
    return _anonymous;
  }

  Future<SteamAppInfo> getAppInfo(int appId, {BigInt? accessToken}) async {
    if (appId <= 0) throw ArgumentError.value(appId, 'appId');
    final client = await _appInfoClient();
    var resolvedToken = accessToken ?? BigInt.zero;
    if (accessToken == null) {
      final tokens = await client.request(
        8905,
        ProtoWriter()..varint(2, appId),
        expectedType: 8906,
      );
      for (final token in ProtoReader(tokens.single.body).messages(3)) {
        if (token.intValue(1) == appId) resolvedToken = token.bigInt(2);
      }
    }
    final packets = await client.request(
      8903,
      ProtoWriter()
        ..message(
          2,
          ProtoWriter()
            ..varint(1, appId)
            ..varint(2, resolvedToken),
        )
        ..varint(7, 1),
      expectedType: 8904,
      done: (packet) => ProtoReader(packet.body).intValue(6) == 0,
    );
    for (final packet in packets) {
      final response = ProtoReader(packet.body);
      for (final app in response.messages(1)) {
        if (app.intValue(1) != appId) continue;
        var buffer = app.bytesValue(5);
        if (buffer == null || buffer.isEmpty) {
          final host = response.stringValue(8);
          final sha = app.bytesValue(4);
          if (host.isEmpty || sha == null) {
            throw const SteamProtocolException(
              'Steam returned app metadata without content',
            );
          }
          final shaText = sha
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final uri = Uri.https(host, '/appinfo/$appId/sha/$shaText.txt.gz');
          final data = await _http
              .get(uri)
              .timeout(const Duration(seconds: 30));
          if (data.statusCode != 200) {
            throw HttpException(
              'Steam appinfo HTTP ${data.statusCode}',
              uri: uri,
            );
          }
          buffer = Uint8List.fromList(gzip.decode(data.bodyBytes));
        }
        return SteamAppInfo.fromData(appId, decodeSteamKeyValues(buffer));
      }
    }
    throw SteamProtocolException(
      'Steam app $appId was not returned; it may require account access',
    );
  }

  Future<Uint8List> getDepotKey(int depotId, int appId) async {
    if (!isLoggedOn) {
      throw const SteamProtocolException(
        'Sign in to Steam before requesting depot keys',
      );
    }
    final packets = await _account.request(
      5438,
      ProtoWriter()
        ..varint(1, depotId)
        ..varint(2, appId),
      expectedType: 5439,
    );
    final response = ProtoReader(packets.single.body);
    final result = response.intValue(1, defaultValue: 2);
    if (result != 1) {
      throw SteamProtocolException(
        'Cannot access depot $depotId',
        result: result,
      );
    }
    final key = response.bytesValue(3);
    if (key == null || key.length != 32) {
      throw const FormatException('Steam returned an invalid depot key');
    }
    return key;
  }

  Future<String> downloadManifest(
    int appId,
    int depotId,
    BigInt manifestGid, {
    Uint8List? depotKey,
    required String destination,
  }) async {
    if (!isLoggedOn) {
      throw const SteamProtocolException('Sign in to download Steam manifests');
    }
    final codeReply = await _account.unified(
      'ContentServerDirectory.GetManifestRequestCode#1',
      ProtoWriter()
        ..varint(1, appId)
        ..varint(2, depotId)
        ..varint(3, manifestGid)
        ..string(4, 'public'),
    );
    final code = ProtoReader(codeReply.body).bigInt(1);
    if (code == BigInt.zero) {
      throw const SteamProtocolException(
        'This Steam account cannot access the manifest',
      );
    }
    final serversReply = await _account.unified(
      'ContentServerDirectory.GetServersForSteamPipe#1',
      ProtoWriter()
        ..varint(1, 0)
        ..varint(2, 6),
    );
    final servers = ProtoReader(serversReply.body)
        .messages(1)
        .where(
          (server) =>
              server.stringValue(8).isNotEmpty && server.intValue(10) == 0,
        )
        .toList();
    if (servers.isEmpty) {
      throw const SteamProtocolException('Steam returned no content servers');
    }
    final server = servers.first;
    final host = server.stringValue(9, defaultValue: server.stringValue(8));
    final uri = Uri.https(
      host,
      '/depot/$depotId/manifest/$manifestGid/5/$code',
    );
    var response = await _http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode == 403) {
      final tokenReply = await _account.unified(
        'ContentServerDirectory.GetCDNAuthToken#1',
        ProtoWriter()
          ..varint(1, depotId)
          ..string(2, host)
          ..varint(3, appId),
      );
      final token = ProtoReader(tokenReply.body).stringValue(1);
      if (token.isEmpty) {
        throw const SteamProtocolException(
          'Steam returned no CDN authorization token',
        );
      }
      final authorized = Uri.parse(
        '${uri.toString()}${token.startsWith('?') ? '' : '?'}$token',
      );
      response = await _http
          .get(authorized)
          .timeout(const Duration(seconds: 45));
    }
    if (response.statusCode != 200) {
      throw HttpException(
        'Steam manifest HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final manifest = DepotManifest.parse(
      response.bodyBytes,
      depotKey: depotKey,
    );
    if (manifest.depotId != depotId || manifest.manifestGid != manifestGid) {
      throw const FormatException(
        'Downloaded Steam manifest does not match the requested depot/version',
      );
    }
    await Directory(destination).create(recursive: true);
    final file = File(p.join(destination, '${depotId}_$manifestGid.manifest'));
    await file.writeAsBytes(manifest.toBytes(), flush: true);
    return file.path;
  }

  Future<SteamExtractionResult> extractApp(
    int appId,
    String destination, {
    TaskContext? task,
    bool includeDlc = true,
    bool downloadManifests = true,
    bool pinManifests = false,
    bool copyAchievements = true,
  }) async {
    if (!isLoggedOn) await restoreSession();
    task?.checkCancelled();
    task?.report('Querying Steam app $appId');
    final main = await getAppInfo(appId);
    final warnings = <String>[];
    final allApps = <SteamAppInfo>[main];
    if (includeDlc) {
      for (final dlcId in main.dlcAppIds) {
        task?.checkCancelled();
        try {
          allApps.add(await getAppInfo(dlcId));
        } catch (error) {
          warnings.add('DLC $dlcId: $error');
        }
      }
    }
    final depots = <int, SteamDepotInfo>{};
    for (final app in allApps) {
      for (final depot in app.depots) {
        depots.putIfAbsent(depot.depotId, () => depot);
      }
    }
    final keys = <int, Uint8List>{};
    var completed = 0;
    for (final depot in depots.values) {
      task?.checkCancelled();
      task?.report(
        'Requesting depot key ${depot.depotId}',
        completed / (depots.length + 1),
      );
      try {
        keys[depot.depotId] = await getDepotKey(depot.depotId, depot.appId);
      } catch (error) {
        warnings.add('Depot ${depot.depotId}: $error');
      }
      completed++;
    }
    if (keys.isEmpty) {
      throw const SteamProtocolException(
        'No authorized depot keys were returned for this account',
      );
    }
    await Directory(destination).create(recursive: true);
    final lua = StringBuffer(
      '-- Generated by FlSteamLua from this Steam account\n\naddappid($appId)\n',
    );
    for (final app in allApps.skip(1)) {
      if (app.depots.isEmpty) lua.writeln('addappid(${app.appId})');
    }
    for (final depot in depots.values) {
      final key = keys[depot.depotId];
      if (key == null) continue;
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      lua.writeln('addappid(${depot.depotId}, 1, "$hex")');
      if (pinManifests && depot.manifestGid != null) {
        lua.writeln('setManifestid(${depot.depotId},"${depot.manifestGid}",0)');
      }
    }
    final luaFile = File(p.join(destination, '$appId.lua'));
    await luaFile.writeAsString(lua.toString(), flush: true);
    final manifests = <String>[];
    if (downloadManifests) {
      for (final depot in depots.values) {
        if (depot.manifestGid == null || !keys.containsKey(depot.depotId)) {
          continue;
        }
        task?.checkCancelled();
        task?.report('Downloading manifest ${depot.depotId}');
        try {
          manifests.add(
            await downloadManifest(
              depot.appId,
              depot.depotId,
              depot.manifestGid!,
              depotKey: keys[depot.depotId],
              destination: destination,
            ),
          );
        } catch (error) {
          warnings.add('Manifest ${depot.depotId}: $error');
        }
      }
    }
    if (copyAchievements && settings.steamPath.isNotEmpty) {
      final stats = Directory(p.join(settings.steamPath, 'appcache', 'stats'));
      if (await stats.exists()) {
        final matches = <File>[];
        await for (final item in stats.list()) {
          if (item is File &&
              RegExp('(^|_)$appId(_|\\.)').hasMatch(p.basename(item.path)) &&
              item.path.toLowerCase().endsWith('.bin')) {
            matches.add(item);
          }
        }
        if (matches.isNotEmpty) {
          matches.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          await matches.first.copy(
            p.join(destination, p.basename(matches.first.path)),
          );
        }
      }
    }
    return SteamExtractionResult(
      luaFile: luaFile.path,
      keyCount: keys.length,
      manifests: manifests,
      warnings: warnings,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_account.close());
    unawaited(_anonymous.close());
    if (_ownsHttp) _http.close();
    super.dispose();
  }
}
