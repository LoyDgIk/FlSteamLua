class SteamProcessActions {
  const SteamProcessActions({
    required this.isRunning,
    required this.start,
    required this.stop,
    required this.restart,
  });

  final Future<bool> Function() isRunning;
  final Future<void> Function() start;
  final Future<void> Function() stop;
  final Future<void> Function() restart;
}

class SteamRunningException implements Exception {
  const SteamRunningException();

  @override
  String toString() => 'Steam is running';
}
