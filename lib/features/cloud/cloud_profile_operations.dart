part of 'cloud_service.dart';

extension CloudProfileOperations on CloudService {
  Future<void> loadProfiles() async {
    if (await _profilesFile.exists()) {
      final data = jsonDecode(await _profilesFile.readAsString());
      if (data is! Map || data['profiles'] is! List) {
        throw const FormatException('Invalid storage profiles');
      }
      _profiles = (data['profiles'] as List)
          .map(
            (v) => CloudStorageProfile.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList();
    }
    final config = await _readConfig();
    _activeStorageId = config['flsteamlua_storage_id'] as String? ?? 'current';
    if (_profiles.every((v) => v.id != _activeStorageId)) {
      _activeStorageId = 'current';
    }
    if (_browsingStorageId != null &&
        !storageProfiles.any((v) => v.id == _browsingStorageId)) {
      _browsingStorageId = null;
    }
  }

  List<CloudStorageProfile> get storageProfiles => [
    if (_activeStorageId == 'current' &&
        !_profiles.any((v) => v.id == 'current'))
      CloudStorageProfile(
        id: 'current',
        name: _l10n.cloudCurrentStorage,
        provider: provider,
        summary: provider == 'folder' ? syncPath : provider,
        folder: syncPath,
      ),
    ..._profiles,
  ];
  List<CloudStorageProfile> get savedStorageProfiles =>
      List.unmodifiable(_profiles);
  bool _nativeCurrent(String id) =>
      id == 'current' && !_profiles.any((v) => v.id == 'current');
  String get activeStorageId => _activeStorageId;
  String get browsingStorageId => _browsingStorageId ?? _activeStorageId;
  CloudStorageProfile storage(String id) =>
      storageProfiles.firstWhere((v) => v.id == id);
  CloudStorageProfile get browsingStorage => storage(browsingStorageId);
  File get _profilesFile => File(paths.file('data/cloud-storages.json'));
  String _profileToken(String id) =>
      p.join(configDirectory, 'profiles', '$id.json');

  Future<void> _saveProfiles() => atomicWrite(
    _profilesFile,
    utf8.encode(
      jsonEncode({'profiles': _profiles.map((v) => v.toJson()).toList()}),
    ),
  );

  Future<Map<String, dynamic>> storageValues(String id) async {
    final profile = storage(id);
    if (profile.provider == 'folder') return {'folder': profile.folder};
    if (_nativeCurrent(id)) {
      final cfg = await _readConfig();
      final token =
          (cfg['token_paths'] as Map?)?[profile.provider] as String? ??
          cfg['token_path'] as String?;
      return await CloudCredentialStore(
            configDirectory,
            credentials.codec,
            overrides: {profile.provider: ?token},
          ).read(profile.provider) ??
          {};
    }
    return await CloudCredentialStore(
          configDirectory,
          credentials.codec,
          overrides: {profile.provider: _profileToken(id)},
        ).read(profile.provider) ??
        {};
  }

  Map<String, dynamic> validateStorage(
    String kind,
    Map<String, dynamic> input,
  ) {
    final values = {...input};
    for (final key in [
      'url',
      'endpoint',
      'region',
      'bucket',
      'account_id',
      'key_prefix',
      'folder',
      'username',
    ]) {
      if (values[key] is String) values[key] = (values[key] as String).trim();
    }
    if (kind == 'folder') {
      if (!p.isAbsolute(values['folder'] as String? ?? '')) {
        throw FormatException(_l10n.cloudFolderAbsolute);
      }
      return values;
    }
    if (kind == 'webdav') {
      final config = WebDavConfig.fromJson(values);
      WebDavRemoteStore(client, config);
      if ([
                'auto',
                'basic',
                'digest',
                'ntlm',
                'negotiate',
              ].contains(config.auth) &&
              config.username.isEmpty ||
          config.auth == 'bearer' && config.bearerToken.isEmpty) {
        throw FormatException(_l10n.cloudCredentialsRequired);
      }
      return config.toJson();
    }
    if (kind == 's3' || kind == 'r2') {
      final normalized = kind == 'r2' ? _r2Config(values) : values;
      S3RemoteStore(client, S3Config.fromJson(normalized));
      return {...normalized};
    }
    if (!{'gdrive', 'onedrive'}.contains(kind)) {
      throw FormatException(_l10n.cloudUnknownStorage);
    }
    if ((values['refresh_token'] as String? ?? '').isEmpty) {
      throw StateError(_l10n.cloudAuthorizeFirst);
    }
    return values;
  }

  Future<RemoteStore> _storeFor(
    String kind,
    Map<String, dynamic> values, {
    Future<void> Function(Map<String, dynamic>)? persist,
  }) async {
    if (_remoteOverride != null && kind != 'folder') return _remoteOverride;
    Future<String> token() => oauth.tokenFor(
      kind,
      values,
      persist ??
          (next) async {
            values.addAll(next);
          },
    );
    return switch (kind) {
      'folder' => FolderRemoteStore(values['folder'] as String),
      'webdav' => WebDavRemoteStore(client, WebDavConfig.fromJson(values)),
      's3' => S3RemoteStore(client, S3Config.fromJson(values)),
      'r2' => S3RemoteStore(client, S3Config.fromJson(_r2Config(values))),
      'gdrive' => GoogleDriveRemoteStore(client, token),
      'onedrive' => OneDriveRemoteStore(client, token),
      _ => throw StateError(_l10n.cloudUnknownStorage),
    };
  }

  Future<RemoteStore> remoteFor(String id) async {
    final profile = storage(id);
    return _storeFor(
      profile.provider,
      await storageValues(id),
      persist: (values) async {
        final cfg = await _readConfig();
        final token = _nativeCurrent(id)
            ? ((cfg['token_paths'] as Map?)?[profile.provider] as String? ??
                  cfg['token_path'] as String? ??
                  credentials.path(profile.provider))
            : _profileToken(id);
        await CloudCredentialStore(
          configDirectory,
          credentials.codec,
          overrides: {profile.provider: token},
        ).write(profile.provider, values);
      },
    );
  }

  CloudTarget _target(String id, String kind, Map<String, dynamic> values) {
    final identity = switch (kind) {
      'folder' => p.normalize(values['folder'] as String),
      'webdav' =>
        '${Uri.parse(values['url'] as String).normalizePath()}|${values['username'] ?? ''}|${values['key_prefix'] ?? ''}|${values['bearer_token'] ?? ''}|${values['extra_headers'] ?? ''}',
      's3' || 'r2' =>
        '${_r2IfNeeded(kind, values)['endpoint']}|${values['bucket']}|${values['key_prefix'] ?? ''}',
      _ => values['remote_account_id'] as String? ?? '',
    };
    if (identity.isEmpty) throw StateError(_l10n.cloudAuthorizeFirst);
    final summary = switch (kind) {
      'folder' => identity,
      'webdav' => '${values['url']} / ${values['key_prefix'] ?? ''}',
      's3' || 'r2' =>
        '${_r2IfNeeded(kind, values)['endpoint']} / ${values['bucket']} / ${values['key_prefix'] ?? ''}',
      _ => values['account_label'] as String? ?? identity,
    };
    return CloudTarget(
      storageId: id,
      provider: kind,
      fingerprint: sha256.convert(utf8.encode('$kind|$identity')).toString(),
      summary: summary,
    );
  }

  Map<String, dynamic> _r2IfNeeded(String kind, Map<String, dynamic> values) =>
      kind == 'r2' ? _r2Config(values) : values;
  Future<CloudTarget> targetFor(String id) async {
    final profile = storage(id);
    return _target(id, profile.provider, await storageValues(id));
  }

  Future<Map<String, dynamic>> authorizeStorage(
    String kind, {
    TaskContext? context,
  }) async {
    final values = await oauth.authorizeDraft(kind, context: context);
    final token = values['access_token'] as String;
    final uri = kind == 'gdrive'
        ? Uri.https('www.googleapis.com', '/drive/v3/about', {
            'fields': 'user(displayName,emailAddress,permissionId)',
          })
        : Uri.https('graph.microsoft.com', '/v1.0/me/drive', {
            r'$select': 'id,owner',
          });
    final response = await client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException(_l10n.cloudAccountLookupFailed);
    }
    final data = jsonDecode(response.body) as Map;
    final user = kind == 'gdrive'
        ? data['user'] as Map
        : (data['owner'] as Map?)?['user'] as Map? ?? {};
    final identity = kind == 'gdrive' ? user['permissionId'] : data['id'];
    if (identity is! String || identity.isEmpty) {
      throw FormatException(_l10n.cloudAccountLookupFailed);
    }
    return {
      ...values,
      'remote_account_id': identity,
      'account_label': user['emailAddress'] ?? user['displayName'] ?? identity,
    };
  }

  Future<CloudConnectionResult> testStorage(
    String kind,
    Map<String, dynamic> draft, {
    bool write = false,
  }) async {
    final values = validateStorage(kind, draft);
    final remote = await _storeFor(
      kind,
      values,
      persist: (next) async {
        draft.addAll(next);
      },
    );
    await remote.testConnection();
    await remote.list('');
    if (write) {
      final path = '.flsteamlua-probe-${DateTime.now().microsecondsSinceEpoch}';
      final data = utf8.encode(path);
      try {
        await remote.write(path, data);
        if (!listEquals(await remote.read(path), data)) {
          throw StateError(_l10n.cloudWriteProbeFailed);
        }
      } finally {
        await remote.delete(path);
      }
    }
    return CloudConnectionResult(
      checkedAt: DateTime.now(),
      writeVerified: write,
      target: _target('draft', kind, values),
    );
  }

  Future<CloudStorageProfile> saveStorage({
    String? id,
    required String name,
    required String kind,
    required Map<String, dynamic> values,
    CloudConnectionResult? tested,
  }) => runMutation(
    () => _saveStorage(
      id: id,
      name: name,
      kind: kind,
      values: values,
      tested: tested,
    ),
  );

  Future<CloudStorageProfile> _saveStorage({
    String? id,
    required String name,
    required String kind,
    required Map<String, dynamic> values,
    CloudConnectionResult? tested,
  }) async {
    if (name.trim().isEmpty) {
      throw FormatException(_l10n.cloudStorageNameRequired);
    }
    final normalized = validateStorage(kind, values);
    final key = id == null || _nativeCurrent(id)
        ? 's${DateTime.now().microsecondsSinceEpoch}'
        : id;
    final target = _target(key, kind, normalized);
    final oldProfiles = [..._profiles];
    final tokenFile = File(_profileToken(key));
    final oldToken = await tokenFile.exists()
        ? await tokenFile.readAsBytes()
        : null;
    try {
      if (kind == 'folder') {
        await Directory(normalized['folder'] as String).create(recursive: true);
      } else {
        await CloudCredentialStore(
          configDirectory,
          credentials.codec,
          overrides: {kind: _profileToken(key)},
        ).write(kind, normalized);
      }
      final profile = CloudStorageProfile(
        id: key,
        name: name.trim(),
        provider: kind,
        summary: target.summary,
        folder: kind == 'folder' ? normalized['folder'] as String : '',
        account: normalized['account_label'] as String? ?? '',
        checkedAt: tested?.target.fingerprint == target.fingerprint
            ? tested?.checkedAt
            : null,
        writeTested:
            tested?.target.fingerprint == target.fingerprint &&
            tested!.writeVerified,
      );
      final index = _profiles.indexWhere((v) => v.id == key);
      if (index < 0) {
        _profiles.add(profile);
      } else {
        _profiles[index] = profile;
      }
      await _saveProfiles();
      // Editing the selected profile updates the same target, not another profile.
      if (id == activeStorageId && key == id) await _activateStorage(key);
      _notify();
      return profile;
    } catch (_) {
      _profiles = oldProfiles;
      if (oldToken != null) {
        await atomicWrite(tokenFile, oldToken);
      } else if (await tokenFile.exists()) {
        await tokenFile.delete();
      }
      await _saveProfiles();
      rethrow;
    }
  }

  Future<void> activateStorage(String id) =>
      runMutation(() => _activateStorage(id));
  Future<void> _activateStorage(String id) async {
    if (id != 'current' &&
        _activeStorageId == 'current' &&
        _nativeCurrent('current')) {
      final current = storage('current');
      final values = await storageValues('current');
      if (current.provider != 'folder' && values.isNotEmpty) {
        await CloudCredentialStore(
          configDirectory,
          credentials.codec,
          overrides: {current.provider: _profileToken('current')},
        ).write(current.provider, values);
      }
      _profiles.insert(0, current);
      await _saveProfiles();
    }
    final profile = storage(id);
    final values = validateStorage(profile.provider, await storageValues(id));
    final before = File(
      paths.file(
        'backups/cloud-config/${DateTime.now().microsecondsSinceEpoch}.json',
      ),
    );
    await atomicWrite(
      before,
      await _configFile.exists()
          ? await _configFile.readAsBytes()
          : utf8.encode('{}'),
    );
    final config = await _readConfig();
    final tokenPath = profile.provider == 'folder'
        ? ''
        : _nativeCurrent(id)
        ? ((config['token_paths'] as Map?)?[profile.provider] as String? ??
              config['token_path'] as String? ??
              credentials.path(profile.provider))
        : _profileToken(id);
    final tokenPaths = Map<String, dynamic>.from(
      config['token_paths'] as Map? ?? {},
    );
    tokenPaths[profile.provider] = tokenPath;
    try {
      await _writeConfig({
        'provider': profile.provider,
        'flsteamlua_storage_id': id,
        if (profile.provider == 'folder') 'sync_path': values['folder'],
        if (profile.provider != 'folder') 'token_path': tokenPath,
        if (profile.provider != 'folder') 'token_paths': tokenPaths,
      });
      _activeStorageId = id;
      if (_browsingStorageId == 'current') _browsingStorageId = null;
      await refreshStatus();
    } catch (_) {
      await atomicWrite(_configFile, await before.readAsBytes());
      await refreshStatus();
      rethrow;
    }
  }

  Future<void> moveActiveFolder(String destination, {TaskContext? context}) =>
      runMutation(() async {
        final profile = storage(activeStorageId);
        final before = await _readConfig();
        await setSyncPath(destination, context: context);
        try {
          if (!_nativeCurrent(profile.id)) {
            await _saveStorage(
              id: profile.id,
              name: profile.name,
              kind: 'folder',
              values: {'folder': destination},
            );
          }
          await _refreshAfterMutation();
        } catch (_) {
          await atomicWrite(_configFile, utf8.encode(jsonEncode(before)));
          await refreshStatus();
          rethrow;
        }
      });

  Future<void> reorderStorages(List<String> ids) => runMutation(() async {
    _profiles = ids
        .map((id) => _profiles.firstWhere((v) => v.id == id))
        .toList();
    await _saveProfiles();
    _notify();
  });

  Future<void> removeStorage(String id) => runMutation(() async {
    if (id == activeStorageId) throw StateError(_l10n.cloudActiveStorageDelete);
    _profiles.removeWhere((v) => v.id == id);
    final file = File(_profileToken(id));
    if (await file.exists()) await file.delete();
    if (_browsingStorageId == id) _browsingStorageId = null;
    await _saveProfiles();
    _notify();
  });

  Future<void> disconnectStorage(String id) => runMutation(() async {
    if (id == activeStorageId && status.enabled) {
      throw StateError(_l10n.cloudDisableBeforeDisconnect);
    }
    final profile = storage(id);
    final config = await _readConfig();
    final file = File(
      _nativeCurrent(id)
          ? ((config['token_paths'] as Map?)?[profile.provider] as String? ??
                config['token_path'] as String? ??
                credentials.path(profile.provider))
          : _profileToken(id),
    );
    if (await file.exists()) await file.delete();
    await refreshStatus();
  });
}
