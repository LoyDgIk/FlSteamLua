import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'wire/cm_packet.dart';
import 'wire/protobuf.dart';

class SteamProtocolException implements Exception {
  const SteamProtocolException(this.message, {this.result});
  final String message;
  final int? result;
  @override
  String toString() =>
      result == null ? message : '$message (Steam EResult $result)';
}

class SteamCmClient {
  SteamCmClient(
    this.httpClient, {
    this.timeout = const Duration(seconds: 30),
    Uri? directoryUri,
    Future<WebSocket> Function(Uri)? socketConnector,
  }) : directoryUri =
           directoryUri ??
           Uri.https(
             'api.steampowered.com',
             '/ISteamDirectory/GetCMListForConnect/v1/',
             {'cellid': '0', 'cmtype': 'websockets'},
           ),
       _socketConnector =
           socketConnector ?? ((uri) => WebSocket.connect(uri.toString()));

  final http.Client httpClient;
  final Duration timeout;
  final Uri directoryUri;
  final Future<WebSocket> Function(Uri) _socketConnector;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  Future<void>? _loggingOn;
  Timer? _heartbeat;
  BigInt steamId = BigInt.zero;
  int sessionId = 0;
  bool isLoggedOn = false;
  void Function()? onStateChanged;
  int _sequence = 0;
  final Map<BigInt, _PendingRequest> _requests = {};
  final Map<int, Completer<CmPacket>> _events = {};
  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect() {
    if (isConnected) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final response = await httpClient.get(directoryUri).timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'Steam CM directory HTTP ${response.statusCode}',
        uri: directoryUri,
      );
    }
    final root = jsonDecode(response.body);
    if (root is! Map || root['response'] is! Map) {
      throw const FormatException('Invalid Steam CM directory response');
    }
    final servers = root['response']['serverlist'];
    if (servers is! List) {
      throw const FormatException('Steam CM directory has no server list');
    }
    Object? lastError;
    // The directory provides weighted server order. A failed connection may use
    // the next supplied server, without replaying any authenticated operation.
    for (final entry in servers.take(4)) {
      if (entry is! Map || entry['endpoint'] is! String) continue;
      try {
        final endpoint = entry['endpoint'] as String;
        final uri = Uri.parse('wss://$endpoint/cmsocket/');
        final socket = await _socketConnector(uri).timeout(timeout);
        _socket = socket;
        _subscription = socket.listen(
          (event) {
            if (identical(_socket, socket)) {
              _receive(event);
            }
          },
          onError: (Object error) {
            if (identical(_socket, socket)) {
              _disconnect(error);
            }
          },
          onDone: () {
            if (identical(_socket, socket)) {
              _disconnect(
                const SteamProtocolException('Steam CM disconnected'),
              );
            }
          },
        );
        final hello = ProtoWriter()..varint(1, 65581);
        send(9805, hello);
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw SteamProtocolException(
      'Cannot connect to a Steam CM server: $lastError',
    );
  }

  void _receive(dynamic event) {
    if (event is! List<int>) {
      _disconnect(
        const FormatException('Steam CM returned a non-binary packet'),
      );
      return;
    }
    try {
      for (final packet in CmPacket.decode(event)) {
        final receivedSteamId = packet.header.bigInt(1);
        if (receivedSteamId != BigInt.zero) steamId = receivedSteamId;
        if (packet.header.field(2) != null) {
          sessionId = packet.header.intValue(2);
        }
        if (packet.messageType == 751) {
          final body = ProtoReader(packet.body);
          isLoggedOn = body.intValue(1, defaultValue: 2) == 1;
          if (isLoggedOn) {
            final seconds = body.intValue(3, defaultValue: 30);
            _heartbeat?.cancel();
            _heartbeat = Timer.periodic(
              Duration(seconds: seconds > 0 ? seconds : 30),
              (_) {
                if (isConnected) send(703, ProtoWriter());
              },
            );
          }
          onStateChanged?.call();
        } else if (packet.messageType == 757) {
          isLoggedOn = false;
          _heartbeat?.cancel();
          onStateChanged?.call();
        }
        final job = packet.header.bigInt(11);
        final request = _requests[job];
        if (request != null &&
            (request.expectedType == null ||
                packet.messageType == request.expectedType)) {
          request.packets.add(packet);
          if (request.done?.call(packet) ?? true) {
            _requests.remove(job);
            request.completer.complete(request.packets);
          }
        }
        final waiter = _events.remove(packet.messageType);
        if (waiter != null && !waiter.isCompleted) waiter.complete(packet);
      }
    } catch (error) {
      _disconnect(error);
    }
  }

  void _disconnect(Object error) {
    isLoggedOn = false;
    _heartbeat?.cancel();
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
    onStateChanged?.call();
    for (final request in _requests.values) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(error);
      }
    }
    _requests.clear();
    for (final waiter in _events.values) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
    _events.clear();
  }

  void send(
    int messageType,
    ProtoWriter body, {
    BigInt? jobId,
    String? target,
  }) {
    if (!isConnected) {
      throw const SteamProtocolException('Steam CM is not connected');
    }
    final header = ProtoWriter()
      ..fixed64(1, steamId)
      ..varint(2, sessionId);
    if (jobId != null) header.fixed64(10, jobId);
    if (target != null) header.string(12, target);
    _socket!.add(CmPacket.encode(messageType, header, body));
  }

  Future<List<CmPacket>> request(
    int messageType,
    ProtoWriter body, {
    int? expectedType,
    String? target,
    bool Function(CmPacket)? done,
  }) async {
    await connect();
    final id =
        BigInt.from(DateTime.now().microsecondsSinceEpoch) +
        BigInt.from(_sequence++);
    final pending = _PendingRequest(expectedType, done);
    _requests[id] = pending;
    try {
      send(messageType, body, jobId: id, target: target);
      return await pending.completer.future.timeout(timeout);
    } finally {
      _requests.remove(id);
    }
  }

  Future<CmPacket> unified(
    String method,
    ProtoWriter body, {
    bool authenticated = true,
  }) async {
    final packets = await request(
      authenticated ? 151 : 9804,
      body,
      expectedType: 147,
      target: method,
    );
    final packet = packets.single;
    final result = packet.header.intValue(13, defaultValue: 1);
    if (result != 1) {
      throw SteamProtocolException(
        packet.header.stringValue(14, defaultValue: method),
        result: result,
      );
    }
    return packet;
  }

  Future<void> logOn({
    String? accountName,
    String? refreshToken,
    BigInt? userSteamId,
  }) {
    if (isLoggedOn) return Future.value();
    return _loggingOn ??= _logOn(
      accountName: accountName,
      refreshToken: refreshToken,
      userSteamId: userSteamId,
    ).whenComplete(() => _loggingOn = null);
  }

  Future<void> _logOn({
    String? accountName,
    String? refreshToken,
    BigInt? userSteamId,
  }) async {
    await connect();
    if (isLoggedOn) return;
    final anonymous = refreshToken == null;
    steamId = anonymous
        ? BigInt.parse('117093590311632896')
        : userSteamId ?? BigInt.parse('76561197960265728');
    sessionId = 0;
    final waiter = Completer<CmPacket>();
    _events[751] = waiter;
    final body = ProtoWriter()
      ..varint(1, 65581)
      ..varint(5, 1771)
      ..string(6, 'english')
      ..varint(7, 20)
      ..varint(3, 0);
    if (!anonymous) {
      body
        ..string(50, accountName!)
        ..string(108, refreshToken)
        ..varint(8, 1)
        ..varint(102, 1)
        ..string(96, 'FlSteamLua');
    }
    send(5514, body);
    try {
      final packet = await waiter.future.timeout(timeout);
      final result = ProtoReader(packet.body).intValue(1, defaultValue: 2);
      if (result != 1) {
        throw SteamProtocolException('Steam logon refused', result: result);
      }
    } finally {
      _events.remove(751);
    }
  }

  Future<void> close() async {
    _heartbeat?.cancel();
    if (isConnected && isLoggedOn) send(706, ProtoWriter());
    await _subscription?.cancel();
    final socket = _socket;
    _disconnect(const SteamProtocolException('Steam session closed'));
    await socket?.close();
  }
}

class _PendingRequest {
  _PendingRequest(this.expectedType, this.done);
  final int? expectedType;
  final bool Function(CmPacket)? done;
  final List<CmPacket> packets = [];
  final completer = Completer<List<CmPacket>>();
}
