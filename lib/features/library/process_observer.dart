import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

class RunningProcess {
  const RunningProcess({required this.pid, required this.executablePath});
  final int pid;
  final String executablePath;
}

typedef ProcessSnapshotReader = Future<List<RunningProcess>> Function();
typedef ObservedProcessStopper = Future<void> Function(RunningProcess process);

Future<void> stopObservedProcess(RunningProcess process) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Stopping observed games requires Windows');
  }
  await Isolate.run(() => _stopWindowsProcess(process));
}

void _stopWindowsProcess(RunningProcess process) {
  final handle = OpenProcess(
    PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE | SYNCHRONIZE,
    FALSE,
    process.pid,
  );
  if (handle == 0) {
    final error = GetLastError();
    if (error == ERROR_INVALID_PARAMETER) return;
    throw WindowsException(HRESULT_FROM_WIN32(error));
  }
  final imageSize = calloc<Uint32>()..value = 32768;
  final image = calloc<Uint16>(32768).cast<Utf16>();
  try {
    if (QueryFullProcessImageName(handle, 0, image, imageSize) == 0) {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
    final currentPath = image.toDartString(length: imageSize.value);
    if (!p.equals(
      p.normalize(currentPath).toLowerCase(),
      p.normalize(process.executablePath).toLowerCase(),
    )) {
      throw StateError('The observed game process has changed');
    }
    // The verified handle identifies this process even if its PID is reused.
    if (TerminateProcess(handle, 1) == 0) {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
    final wait = WaitForSingleObject(handle, 5000);
    if (wait == WAIT_FAILED) {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
    if (wait == WAIT_TIMEOUT) throw StateError('Game process did not exit');
  } finally {
    calloc.free(image);
    calloc.free(imageSize);
    CloseHandle(handle);
  }
}

/// Uses image paths rather than process names, so another game's same-named
/// executable cannot trigger a binding. Protected processes are not inspected.
Future<List<RunningProcess>> readRunningProcesses() async {
  if (!Platform.isWindows) return const [];
  return Isolate.run(_readWindowsProcesses);
}

List<RunningProcess> _readWindowsProcesses() {
  var capacity = 1024;
  final needed = calloc<Uint32>();
  final imageSize = calloc<Uint32>();
  final image = calloc<Uint16>(32768).cast<Utf16>();
  Pointer<Uint32> processIds = nullptr;
  try {
    while (true) {
      if (processIds != nullptr) calloc.free(processIds);
      processIds = calloc<Uint32>(capacity);
      final bytes = capacity * sizeOf<Uint32>();
      if (EnumProcesses(processIds, bytes, needed) == 0) {
        throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
      }
      if (needed.value < bytes) break;
      capacity *= 2;
    }
    final processes = <RunningProcess>[];
    for (var index = 0; index < needed.value ~/ sizeOf<Uint32>(); index++) {
      final pid = processIds[index];
      if (pid == 0) continue;
      final handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
      if (handle == 0) continue;
      try {
        imageSize.value = 32768;
        if (QueryFullProcessImageName(handle, 0, image, imageSize) != 0) {
          processes.add(
            RunningProcess(
              pid: pid,
              executablePath: image.toDartString(length: imageSize.value),
            ),
          );
        }
      } finally {
        CloseHandle(handle);
      }
    }
    return processes;
  } finally {
    if (processIds != nullptr) calloc.free(processIds);
    calloc.free(image);
    calloc.free(imageSize);
    calloc.free(needed);
  }
}
