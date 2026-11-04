import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

Future<List<String>> loadSystemFontFamilies() async {
  if (!Platform.isWindows) return const [];
  return Future<List<String>>(_enumerateWindowsFonts);
}

List<String> _enumerateWindowsFonts() {
  final families = <String>{};
  final logFont = calloc<LOGFONT>();
  final deviceContext = GetDC(0);
  if (deviceContext == 0) {
    calloc.free(logFont);
    return const [];
  }
  final callback = NativeCallable<FONTENUMPROC>.isolateLocal((
    Pointer<LOGFONT> font,
    Pointer<TEXTMETRIC> metrics,
    int fontType,
    int parameter,
  ) {
    final family = font.ref.lfFaceName.trim();
    if (family.isNotEmpty && !family.startsWith('@')) {
      families.add(family);
    }
    return 1;
  }, exceptionalReturn: 0);
  try {
    logFont.ref.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesEx(deviceContext, logFont, callback.nativeFunction, 0, 0);
  } finally {
    callback.close();
    calloc.free(logFont);
    ReleaseDC(0, deviceContext);
  }
  return families.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
