import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Blocking byte pipe, used only in a dedicated isolate or worker process.
class WindowsNamedPipe {
  WindowsNamedPipe._(this._handle);
  final int _handle;
  bool _closed = false;
  final List<int> _pending = [];
  static const int _invalidHandle = -1;
  static final DynamicLibrary _kernel = DynamicLibrary.open('kernel32.dll');

  static final _createServer = _kernel
      .lookupFunction<
        IntPtr Function(
          Pointer<Utf16>,
          Uint32,
          Uint32,
          Uint32,
          Uint32,
          Uint32,
          Uint32,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Utf16>,
          int,
          int,
          int,
          int,
          int,
          int,
          Pointer<Void>,
        )
      >('CreateNamedPipeW');
  static final _connect = _kernel
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Void>),
        int Function(int, Pointer<Void>)
      >('ConnectNamedPipe');
  static final _open = _kernel
      .lookupFunction<
        IntPtr Function(
          Pointer<Utf16>,
          Uint32,
          Uint32,
          Pointer<Void>,
          Uint32,
          Uint32,
          IntPtr,
        ),
        int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int)
      >('CreateFileW');
  static final _read = _kernel
      .lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<Uint8>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Void>,
        ),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
      >('ReadFile');
  static final _write = _kernel
      .lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<Uint8>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Void>,
        ),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>)
      >('WriteFile');
  static final _peek = _kernel
      .lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<Void>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          Pointer<Void>,
          int,
          Pointer<Uint32>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        )
      >('PeekNamedPipe');
  static final _closeHandle = _kernel
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  static final _lastError = _kernel
      .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

  static WindowsNamedPipe accept(String name) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Named pipes require Windows');
    }
    _lastError();
    final path = _path(name).toNativeUtf16();
    try {
      final handle = _createServer(
        path,
        3 | 0x00080000,
        8,
        1,
        65536,
        65536,
        0,
        nullptr,
      );
      if (handle == _invalidHandle) _fail('CreateNamedPipe');
      if (_connect(handle, nullptr) == 0 && _lastError() != 535) {
        final code = _lastError();
        _closeHandle(handle);
        throw FileSystemException(
          'ConnectNamedPipe failed',
          null,
          OSError('Win32', code),
        );
      }
      return WindowsNamedPipe._(handle);
    } finally {
      calloc.free(path);
    }
  }

  static WindowsNamedPipe connect(
    String name, {
    Duration timeout = const Duration(seconds: 25),
  }) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Named pipes require Windows');
    }
    _lastError();
    final path = _path(name).toNativeUtf16();
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final handle = _open(path, 0xC0000000, 0, nullptr, 3, 0, 0);
        if (handle != _invalidHandle) return WindowsNamedPipe._(handle);
        final error = _lastError();
        if (error != 2 && error != 231) {
          throw FileSystemException(
            'Could not connect to Steam worker',
            null,
            OSError('Win32', error),
          );
        }
        if (watch.elapsed >= timeout) {
          throw const PipeTimeout('Steam worker did not open its pipe');
        }
        sleep(const Duration(milliseconds: 30));
      }
    } finally {
      calloc.free(path);
    }
  }

  static String _path(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,180}$').hasMatch(name)) {
      throw const FormatException('Invalid worker pipe name');
    }
    return '\\\\.\\pipe\\$name';
  }

  static Never _fail(String action) => throw FileSystemException(
    '$action failed',
    null,
    OSError('Win32', _lastError()),
  );

  void writeJson(Map<String, dynamic> json) {
    if (_closed) throw StateError('Pipe is closed');
    final bytes = Uint8List.fromList(utf8.encode('${jsonEncode(json)}\n'));
    if (bytes.length > 16 * 1024 * 1024) {
      throw const FormatException('Worker message exceeds 16 MiB');
    }
    final buffer = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        if (_write(
              _handle,
              buffer + offset,
              bytes.length - offset,
              written,
              nullptr,
            ) ==
            0) {
          _fail('WriteFile');
        }
        if (written.value == 0) {
          throw const FileSystemException('Worker pipe closed while writing');
        }
        offset += written.value;
      }
    } finally {
      calloc.free(buffer);
      calloc.free(written);
    }
  }

  Map<String, dynamic>? readJson({Duration? timeout}) {
    if (_closed) throw StateError('Pipe is closed');
    final watch = Stopwatch()..start();
    final buffer = calloc<Uint8>(65536);
    final readCount = calloc<Uint32>();
    final available = calloc<Uint32>();
    try {
      while (true) {
        final newline = _pending.indexOf(10);
        if (newline >= 0) {
          final line = _pending.sublist(0, newline);
          _pending.removeRange(0, newline + 1);
          final json = jsonDecode(utf8.decode(line));
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid worker response');
          }
          return json;
        }
        var length = 65536;
        if (timeout != null) {
          if (watch.elapsed >= timeout) {
            throw const PipeTimeout('Steam worker response timed out');
          }
          if (_peek(_handle, nullptr, 0, nullptr, available, nullptr) == 0) {
            if (_lastError() == 109 || _lastError() == 232) return null;
            _fail('PeekNamedPipe');
          }
          if (available.value == 0) {
            sleep(const Duration(milliseconds: 10));
            continue;
          }
          length = min(length, available.value);
        }
        if (_read(_handle, buffer, length, readCount, nullptr) == 0) {
          if (_lastError() == 109 || _lastError() == 232) return null;
          _fail('ReadFile');
        }
        if (readCount.value == 0) return null;
        _pending.addAll(buffer.asTypedList(readCount.value));
        if (_pending.length > 16 * 1024 * 1024) {
          throw const FormatException('Worker response exceeds 16 MiB');
        }
      }
    } finally {
      calloc.free(buffer);
      calloc.free(readCount);
      calloc.free(available);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _closeHandle(_handle);
  }
}

class PipeTimeout implements Exception {
  const PipeTimeout(this.message);
  final String message;
  @override
  String toString() => message;
}
