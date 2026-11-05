import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import 'cloud_service.dart';
import 'cloud_workflows.dart';

class CloudStorageForm extends StatefulWidget {
  const CloudStorageForm({
    super.key,
    required this.initialProvider,
    required this.initialValues,
    required this.service,
    this.profileId,
    this.initialName = '',
  });

  final CloudService service;
  final String? profileId;
  final String initialName;
  final String initialProvider;
  final Map<String, dynamic> initialValues;

  @override
  State<CloudStorageForm> createState() => CloudStorageFormState();
}

class CloudStorageFormState extends State<CloudStorageForm> {
  static const _fields = [
    'folder',
    'url',
    'username',
    'password',
    'bearer_token',
    'account_id',
    'access_key_id',
    'secret_access_key',
    'bucket',
    'endpoint',
    'region',
    'key_prefix',
    'extra_headers',
    'timeout_sec',
  ];

  static const _connectionFields = {
    'folder': ['folder'],
    'webdav': ['url'],
    's3': ['endpoint', 'region', 'bucket'],
    'r2': ['account_id', 'endpoint', 'bucket'],
  };

  static const _credentialFields = {
    'webdav': ['username', 'password', 'bearer_token'],
    's3': ['access_key_id', 'secret_access_key'],
    'r2': ['access_key_id', 'secret_access_key'],
  };

  static const _advancedFields = {
    'webdav': ['key_prefix', 'extra_headers', 'timeout_sec'],
    's3': ['key_prefix'],
    'r2': ['key_prefix'],
  };

  late String _provider = widget.initialProvider;
  late String _auth = widget.initialValues['auth'] as String? ?? 'basic';
  late bool _allowHttp = widget.initialValues['allow_insecure_http'] == true;
  late bool _allowInsecureTls =
      widget.initialValues['allow_insecure_tls'] == true;
  late bool _signPayload = widget.initialValues['sign_payload'] == true;
  final _controllers = <String, TextEditingController>{};
  final _drafts = <String, Map<String, dynamic>>{};
  final _invalid = <String>{};
  bool _saving = false;
  String? _error;
  bool _dirty = false;
  late final _name = TextEditingController(text: widget.initialName);
  late Map<String, dynamic> _tokens = {...widget.initialValues};
  CloudConnectionResult? _tested;

  void _edited() {
    _dirty = true;
    _tested = null;
  }

  Future<bool> _canClose(BuildContext context) async {
    if (_saving) return false;
    if (!_dirty) return true;
    return await ui.AppDialogs.confirm(
          context,
          title: context.l10n.cloudDiscardDraft,
          message: context.l10n.cloudDiscardDraft,
          confirmText: context.l10n.discard,
        ) ==
        true;
  }

  Future<void> _cancel() async {
    if (await _canClose(context) && mounted) Navigator.of(context).pop();
  }

  Future<void> _authorize() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tokens = await widget.service.authorizeStorage(_provider);
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _edited();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(bool write) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = _values();
      final result = await widget.service.testStorage(
        _provider,
        draft,
        write: write,
      );
      if (mounted) {
        setState(() {
          _tested = result;
          if (['gdrive', 'onedrive'].contains(_provider)) _tokens = draft;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> get _credentials => _provider != 'webdav'
      ? _credentialFields[_provider] ?? const []
      : switch (_auth) {
          'none' => const [],
          'bearer' => const ['bearer_token'],
          _ => const ['username', 'password'],
        };

  Set<String> get _required => switch (_provider) {
    'folder' => {'folder'},
    'webdav' => {'url', ..._credentials.where((key) => key != 'password')},
    's3' => {
      'endpoint',
      'region',
      'bucket',
      'access_key_id',
      'secret_access_key',
    },
    'r2' => {
      'bucket',
      'access_key_id',
      'secret_access_key',
      if (_controllers['endpoint']!.text.trim().isEmpty) 'account_id',
    },
    _ => {},
  };

  Future<void> _switchProvider(String provider) async {
    _drafts[_provider] = _values();
    setState(() => _saving = true);
    try {
      final values = _drafts[provider] ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _provider = provider;
        _tokens = {...values};
        _edited();
        for (final entry in _controllers.entries) {
          final value = values[entry.key];
          entry.value.text = value is List
              ? value.join('\n')
              : value?.toString() ?? (entry.key == 'region' ? 'auto' : '');
        }
        _auth = values['auth'] as String? ?? 'basic';
        _allowHttp = values['allow_insecure_http'] == true;
        _allowInsecureTls = values['allow_insecure_tls'] == true;
        _signPayload = values['sign_payload'] == true;
        _invalid.clear();
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      final value = widget.initialValues[field];
      _controllers[field] = TextEditingController(
        text: value is List
            ? value.join('\n')
            : value?.toString() ?? (field == 'region' ? 'auto' : ''),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _name.dispose();
    super.dispose();
  }

  String _fieldLabel(BuildContext context, String field) => switch (field) {
    'folder' => context.l10n.localSaveFolder,
    'url' => context.l10n.url,
    'username' => context.l10n.accountName,
    'password' => context.l10n.password,
    'bearer_token' => context.l10n.bearerToken,
    'account_id' => context.l10n.accountId,
    'access_key_id' => context.l10n.accessKeyId,
    'secret_access_key' => context.l10n.secretAccessKey,
    'bucket' => context.l10n.bucket,
    'endpoint' => context.l10n.endpoint,
    'region' => context.l10n.region,
    'key_prefix' => context.l10n.keyPrefix,
    'extra_headers' => context.l10n.extraHeaders,
    'timeout_sec' => context.l10n.timeoutSeconds,
    _ => field,
  };

  Widget _fieldRow(String field) {
    final controller = _controllers[field]!;
    final secret = {
      'password',
      'bearer_token',
      'secret_access_key',
    }.contains(field);
    final fieldWidget = secret
        ? ui.FormRowSecretTextField(
            controller: controller,
            hintText: _required.contains(field)
                ? context.l10n.requiredField
                : context.l10n.optional,
            enabled: !_saving,
            onChanged: (_) => setState(() {
              _edited();
              _invalid.remove(field);
              _error = null;
            }),
          )
        : ui.FormRowTextField(
            controller: controller,
            hintText: _required.contains(field)
                ? context.l10n.requiredField
                : context.l10n.optional,
            enabled: !_saving,
            onChanged: (_) => setState(() {
              _edited();
              _invalid.remove(field);
              _error = null;
            }),
            keyboardType: field == 'timeout_sec'
                ? TextInputType.number
                : field == 'url' || field == 'endpoint'
                ? TextInputType.url
                : TextInputType.text,
            maxLines: field == 'extra_headers' ? 3 : 1,
          );
    return ui.FormRow(
      key: ValueKey('cloud-field-$field'),
      invalid: _invalid.contains(field),
      title: _fieldLabel(context, field),
      trailing: fieldWidget,
    );
  }

  Widget _section(String title, Iterable<String> fields) {
    return ui.generateSection(
      title: title,
      items: [for (final field in fields) _fieldRow(field)],
    );
  }

  Map<String, dynamic> _values() {
    final fields = [
      ...?_connectionFields[_provider],
      ..._credentials,
      ...?_advancedFields[_provider],
    ];
    final result = <String, dynamic>{
      if (['gdrive', 'onedrive'].contains(_provider)) ..._tokens,
      for (final field in fields) field: _controllers[field]!.text,
    };
    if (_provider == 'webdav') {
      result['auth'] = _auth;
      result['allow_insecure_tls'] = _allowInsecureTls;
      final timeout = _controllers['timeout_sec']!.text.trim();
      result['timeout_sec'] = timeout.isEmpty
          ? 30
          : int.tryParse(timeout) ?? -1;
    }
    result['allow_insecure_http'] = _allowHttp;
    result['sign_payload'] = _signPayload;
    return result;
  }

  Future<void> _save() async {
    _invalid.clear();
    for (final field in _required) {
      if (_controllers[field]!.text.trim().isEmpty) _invalid.add(field);
    }
    if (_invalid.isNotEmpty) {
      setState(
        () => _error = context.l10n.fillRequiredFields(
          _invalid.map((field) => _fieldLabel(context, field)).join('、'),
        ),
      );
      return;
    }
    for (final field in ['url', 'endpoint']) {
      if (!(_connectionFields[_provider] ?? const []).contains(field)) continue;
      final raw = _controllers[field]!.text.trim();
      if (raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          !{'https', if (_allowHttp) 'http'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        setState(() {
          _invalid.add(field);
          _error = context.l10n.cloudAddressInvalid;
        });
        return;
      }
    }
    final values = _values();
    if (_provider == 'webdav' &&
        ((values['timeout_sec'] as int) < 0 ||
            (values['timeout_sec'] as int) > 300)) {
      setState(() {
        _invalid.add('timeout_sec');
        _error = context.l10n.cloudTimeoutInvalid;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveStorage(
        id: widget.profileId,
        name: _name.text,
        kind: _provider,
        values: values,
        tested: _tested,
      );
      _dirty = false;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = ui.appErrorText(context, error));
        ui.showAppError(context, error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionFields = _connectionFields[_provider] ?? const <String>[];
    final credentialFields = _credentials;
    final advancedFields = _advancedFields[_provider] ?? const <String>[];
    return ui.CommonPopScope(
      onPop: _canClose,
      child: ui.FormPage(
        title: context.l10n.configureStorage,
        onSave: _save,
        onCancel: _cancel,
        saving: _saving,
        error: _error,
        children: [
          ui.generateSection(
            title: context.l10n.basicInfo,
            items: [
              ui.FormRow(
                title: context.l10n.cloudStorageName,
                trailing: ui.FormRowTextField(
                  key: const ValueKey('cloud-storage-name'),
                  controller: _name,
                  enabled: !_saving,
                  onChanged: (_) => setState(_edited),
                ),
              ),
              ui.FormRowSelect<String>(
                title: context.l10n.provider,
                value: _provider,
                enabled: !_saving,
                options: [
                  for (final provider in CloudService.providers)
                    (provider, cloudProviderName(context, provider)),
                ],
                onChanged: (value) {
                  if (value != null) unawaited(_switchProvider(value));
                },
              ),
              if (_provider == 'webdav')
                ui.FormRowSelect<String>(
                  title: context.l10n.authentication,
                  value: _auth,
                  enabled: !_saving,
                  options: [
                    for (final value in [
                      'basic',
                      'auto',
                      'digest',
                      'ntlm',
                      'negotiate',
                      'bearer',
                      'none',
                    ])
                      (value, value),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _auth = value;
                        _edited();
                        _invalid.clear();
                        _error = null;
                      });
                    }
                  },
                ),
              for (final field in connectionFields) _fieldRow(field),
              if (_provider == 'folder')
                ui.DecorationListItem(
                  title: Text(context.l10n.chooseAFolder),
                  onPressed: _saving
                      ? null
                      : () async {
                          final path = await FilePicker.platform
                              .getDirectoryPath();
                          if (path != null && mounted) {
                            setState(() {
                              _controllers['folder']!.text = path;
                              _edited();
                            });
                          }
                        },
                ),
            ],
          ),
          if (['gdrive', 'onedrive'].contains(_provider))
            ui.generateSection(
              items: [
                ui.DecorationListItem(
                  title: Text(context.l10n.authorize),
                  subtitle: Text(
                    _tokens['account_label'] as String? ??
                        context.l10n.cloudAuthorizeFirst,
                  ),
                  onPressed: _saving ? null : _authorize,
                  trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                ),
              ],
            ),
          if (_provider == 'webdav' && ['ntlm', 'negotiate'].contains(_auth))
            ui.ListFooter(
              text: context
                  .l10n
                  .usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain,
            ),
          if (credentialFields.isNotEmpty)
            _section(context.l10n.credentials, credentialFields),
          if (advancedFields.isNotEmpty ||
              ['webdav', 's3', 'r2'].contains(_provider))
            ui.CollapsibleSection(
              label: context.l10n.advanced,
              initiallyExpanded: false,
              showCount: false,
              itemCount: 1,
              itemBuilder: (_, _) => ui.generateSection(
                items: [
                  for (final field in advancedFields) _fieldRow(field),
                  ui.FormRowSwitch(
                    title: context
                        .l10n
                        .allowHttpCredentialsAndSavesAreSentWithoutEncryption,
                    value: _allowHttp,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _allowHttp = value;
                            _edited();
                          }),
                  ),
                  if (_provider == 'webdav')
                    ui.FormRowSwitch(
                      title: context
                          .l10n
                          .skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly,
                      value: _allowInsecureTls,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _allowInsecureTls = value;
                              _edited();
                            }),
                    ),
                  if (['s3', 'r2'].contains(_provider))
                    ui.FormRowSwitch(
                      title: context.l10n.signRequestPayload,
                      value: _signPayload,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _signPayload = value;
                              _edited();
                            }),
                    ),
                ],
              ),
            ),
          ui.generateSection(
            title: context.l10n.testConnection,
            items: [
              ui.DecorationListItem(
                title: Text(context.l10n.cloudTestRead),
                subtitle: Text(
                  _tested == null
                      ? context.l10n.cloudNotTested
                      : _tested!.writeVerified
                      ? context.l10n.cloudWriteVerified
                      : context.l10n.cloudReadVerified,
                ),
                onPressed: _saving ? null : () => _test(false),
              ),
              ui.DecorationListItem(
                title: Text(context.l10n.cloudTestWrite),
                subtitle: Text(context.l10n.cloudTestWriteHint),
                onPressed: _saving ? null : () => _test(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
