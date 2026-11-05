import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/task_center.dart';
import 'cloud_credentials.dart';

class CloudOAuth {
  CloudOAuth({
    required this.client,
    required this.credentials,
    required this.openBrowser,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final http.Client client;
  final CloudCredentialStore credentials;
  final Future<bool> Function(Uri) openBrowser;
  final DateTime Function() clock;
  HttpServer? _server;

  static const googleClientId =
      '1072944905499-vm2v2i5dvn0a0d2o4ca36i1vge8cvbn0.apps.googleusercontent.com';
  static const googleClientSecret = 'v6V3fKV_zWU7iw1DrpO1rknX';
  static const oneDriveClientId = 'b15665d9-eda6-4092-8539-0eec376afd59';
  static const oneDriveClientSecret = 'qtyfaBBYA403=unZUP40~_#';

  static String codeChallenge(String verifier) => base64Url
      .encode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');

  static String callbackCode(Uri callback, String expectedState) {
    if (callback.queryParameters['state'] != expectedState) {
      throw const FormatException('OAuth state mismatch');
    }
    final error = callback.queryParameters['error'];
    if (error != null) throw StateError('OAuth authorization failed: $error');
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const FormatException('OAuth callback has no code');
    }
    return code;
  }

  Future<void> authorize(String provider, {TaskContext? context}) async {
    await credentials.write(
      provider,
      await authorizeDraft(provider, context: context),
    );
  }

  Future<Map<String, dynamic>> authorizeDraft(
    String provider, {
    TaskContext? context,
  }) async {
    final config = _config(provider);
    if (_server != null) {
      throw StateError('Another authorization is in progress');
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      provider == 'onedrive' ? 53682 : 0,
    );
    _server = server;
    final redirect = Uri.parse(
      'http://localhost:${server.port}/${provider == 'gdrive' ? 'callback' : ''}',
    );
    final state = _random(32);
    final verifier = _random(64);
    final uri = Uri.parse(config.authUrl).replace(
      queryParameters: {
        'client_id': config.clientId,
        'redirect_uri': redirect.toString(),
        'response_type': 'code',
        'scope': config.scope,
        'state': state,
        'code_challenge': codeChallenge(verifier),
        'code_challenge_method': 'S256',
        'prompt': 'consent',
        if (provider == 'gdrive') 'access_type': 'offline',
      },
    );
    try {
      if (!await openBrowser(uri)) {
        throw StateError('Could not open authorization browser');
      }
      context?.report('Waiting for authorization in your browser');
      final code = Completer<String>();
      final subscription = server.listen((request) async {
        if (!request.uri.queryParameters.containsKey('state')) {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        }
        try {
          final value = callbackCode(request.uri, state);
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<html><meta charset="utf-8"><body>Authorization received. You can close this window.</body></html>',
          );
          if (!code.isCompleted) code.complete(value);
        } catch (error, stack) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(
            'Authorization rejected. Return to the application.',
          );
          if (!code.isCompleted) code.completeError(error, stack);
        } finally {
          await request.response.close();
        }
      });
      final timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (context?.isCancelled == true && !code.isCompleted) {
          code.completeError(const TaskCancelled());
        }
      });
      try {
        final authCode = await code.future.timeout(const Duration(minutes: 5));
        context?.checkCancelled();
        final tokens = await _tokenRequest(config, {
          'code': authCode,
          'redirect_uri': redirect.toString(),
          'grant_type': 'authorization_code',
          'code_verifier': verifier,
        });
        if ((tokens['refresh_token'] as String? ?? '').isEmpty) {
          throw StateError(
            'Authorization did not return an offline refresh token',
          );
        }
        return tokens;
      } finally {
        timer.cancel();
        await subscription.cancel();
      }
    } finally {
      await server.close(force: true);
      _server = null;
    }
  }

  Future<String> accessToken(String provider) async {
    final value = await credentials.read(provider);
    if (value == null) throw StateError('Connect $provider first');
    return tokenFor(
      provider,
      value,
      (tokens) => credentials.write(provider, tokens),
    );
  }

  Future<String> tokenFor(
    String provider,
    Map<String, dynamic> value,
    Future<void> Function(Map<String, dynamic>) persist,
  ) async {
    final expiry = (value['expires_at'] as num?)?.toInt() ?? 0;
    final token = value['access_token'] as String? ?? '';
    if (token.isNotEmpty &&
        expiry > clock().millisecondsSinceEpoch ~/ 1000 + 120) {
      return token;
    }
    final refresh = value['refresh_token'] as String? ?? '';
    if (refresh.isEmpty) {
      throw StateError('Cloud login has expired; connect again');
    }
    final tokens = await _tokenRequest(_config(provider), {
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
    });
    tokens['refresh_token'] ??= refresh;
    value.addAll(tokens);
    await persist(value);
    return tokens['access_token'] as String;
  }

  Future<Map<String, dynamic>> _tokenRequest(
    _OAuthConfig config,
    Map<String, String> fields,
  ) async {
    final response = await client
        .post(
          Uri.parse(config.tokenUrl),
          body: {
            ...fields,
            'client_id': config.clientId,
            'client_secret': config.clientSecret,
            if (config.provider == 'onedrive') 'scope': config.scope,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OAuth token endpoint returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['access_token'] is! String) {
      throw const FormatException('Invalid OAuth token response');
    }
    return {
      'access_token': decoded['access_token'],
      if (decoded['refresh_token'] is String)
        'refresh_token': decoded['refresh_token'],
      'expires_at':
          clock().millisecondsSinceEpoch ~/ 1000 +
          ((decoded['expires_in'] as num?)?.toInt() ?? 3600),
    };
  }

  static String _random(int length) {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(length, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static _OAuthConfig _config(String provider) => switch (provider) {
    'gdrive' => const _OAuthConfig(
      'gdrive',
      googleClientId,
      googleClientSecret,
      'https://accounts.google.com/o/oauth2/v2/auth',
      'https://oauth2.googleapis.com/token',
      'https://www.googleapis.com/auth/drive.file',
    ),
    'onedrive' => const _OAuthConfig(
      'onedrive',
      oneDriveClientId,
      oneDriveClientSecret,
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      'Files.ReadWrite offline_access',
    ),
    _ => throw ArgumentError.value(provider, 'provider'),
  };
}

class _OAuthConfig {
  const _OAuthConfig(
    this.provider,
    this.clientId,
    this.clientSecret,
    this.authUrl,
    this.tokenUrl,
    this.scope,
  );
  final String provider, clientId, clientSecret, authUrl, tokenUrl, scope;
}
