import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const defaultThemeColor = 0xff007aff;

int systemAccentColor() {
  if (!Platform.isWindows) return defaultThemeColor;
  final color = calloc<Uint32>();
  final opaque = calloc<Int32>();
  try {
    final result = DwmGetColorizationColor(color, opaque);
    if (result != S_OK) return defaultThemeColor;
    return 0xff000000 | (color.value & 0x00ffffff);
  } catch (_) {
    return defaultThemeColor;
  } finally {
    calloc
      ..free(color)
      ..free(opaque);
  }
}
