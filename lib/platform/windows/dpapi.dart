import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int length;
  external Pointer<Uint8> bytes;
}

typedef _ProtectNative =
    Int32 Function(
      Pointer<_DataBlob>,
      Pointer<Utf16>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_DataBlob>,
    );
typedef _ProtectDart =
    int Function(
      Pointer<_DataBlob>,
      Pointer<Utf16>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_DataBlob>,
    );
typedef _UnprotectNative =
    Int32 Function(
      Pointer<_DataBlob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_DataBlob>,
    );
typedef _UnprotectDart =
    int Function(
      Pointer<_DataBlob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_DataBlob>,
    );

/// Current-user Windows encryption. Null entropy preserves CloudRedirect's ABI.
abstract final class WindowsDpapi {
  static Uint8List protectBytes(Uint8List bytes, {Uint8List? entropy}) =>
      _transform(bytes, entropy: entropy, protect: true);

  static Uint8List unprotectBytes(Uint8List bytes, {Uint8List? entropy}) =>
      _transform(bytes, entropy: entropy, protect: false);

  static String protectString(String value, {String? entropy}) => base64Encode(
    protectBytes(
      Uint8List.fromList(utf8.encode(value)),
      entropy: entropy == null
          ? null
          : Uint8List.fromList(utf8.encode(entropy)),
    ),
  );

  static String unprotectString(String value, {String? entropy}) => utf8.decode(
    unprotectBytes(
      base64Decode(value),
      entropy: entropy == null
          ? null
          : Uint8List.fromList(utf8.encode(entropy)),
    ),
  );

  static Uint8List _transform(
    Uint8List bytes, {
    required bool protect,
    Uint8List? entropy,
  }) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows DPAPI is only available on Windows');
    }
    final crypt = DynamicLibrary.open('crypt32.dll');
    final kernel = DynamicLibrary.open('kernel32.dll');
    final localFree = kernel
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('LocalFree');
    final getLastError = kernel
        .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
    final input = calloc<_DataBlob>();
    final output = calloc<_DataBlob>();
    final inputBytes = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    final entropyBlob = entropy == null
        ? nullptr.cast<_DataBlob>()
        : calloc<_DataBlob>();
    final entropyBytes = entropy == null
        ? nullptr.cast<Uint8>()
        : calloc<Uint8>(entropy.isEmpty ? 1 : entropy.length);
    try {
      inputBytes.asTypedList(bytes.length).setAll(0, bytes);
      input.ref
        ..length = bytes.length
        ..bytes = inputBytes;
      if (entropy != null) {
        entropyBytes.asTypedList(entropy.length).setAll(0, entropy);
        entropyBlob.ref
          ..length = entropy.length
          ..bytes = entropyBytes;
      }
      final result = protect
          ? crypt.lookupFunction<_ProtectNative, _ProtectDart>(
              'CryptProtectData',
            )(input, nullptr, entropyBlob, nullptr, nullptr, 1, output)
          : crypt.lookupFunction<_UnprotectNative, _UnprotectDart>(
              'CryptUnprotectData',
            )(input, nullptr, entropyBlob, nullptr, nullptr, 1, output);
      if (result == 0) {
        throw FileSystemException(
          'Windows could not ${protect ? 'encrypt' : 'decrypt'} the credential',
          null,
          OSError('DPAPI failed', getLastError()),
        );
      }
      return Uint8List.fromList(
        output.ref.bytes.asTypedList(output.ref.length),
      );
    } finally {
      inputBytes.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      calloc.free(inputBytes);
      if (entropy != null) {
        entropyBytes
            .asTypedList(entropy.length)
            .fillRange(0, entropy.length, 0);
        calloc.free(entropyBytes);
        calloc.free(entropyBlob);
      }
      if (output.ref.bytes != nullptr) {
        output.ref.bytes
            .asTypedList(output.ref.length)
            .fillRange(0, output.ref.length, 0);
        localFree(output.ref.bytes.cast());
      }
      calloc.free(input);
      calloc.free(output);
    }
  }
}
