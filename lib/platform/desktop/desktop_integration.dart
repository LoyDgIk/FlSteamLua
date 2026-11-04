import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/settings_store.dart';
import '../../ui/localization.dart';

/// Owns desktop resources for the application's lifetime, not a page's lifetime.
class DesktopIntegration with WindowListener, TrayListener {
  DesktopIntegration({
    required this.settings,
    this.onExitRequested,
    this.onShowRequested,
    this.onRestartSteam,
    this.onError,
  });

  final SettingsStore settings;
  final Future<void> Function()? onExitRequested;
  final VoidCallback? onShowRequested;
  final Future<void> Function()? onRestartSteam;
  final void Function(Object error)? onError;
  bool _initialized = false;
  bool _trayAvailable = false;
  bool _quitting = false;
  bool _disposed = false;
  bool get trayAvailable => _trayAvailable;

  Future<void> initialize() async {
    if (!Platform.isWindows || _initialized) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    trayManager.addListener(this);
    settings.addListener(_settingsChanged);
    _initialized = true;
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'FlSteamLua',
        size: Size(1280, 820),
        minimumSize: Size(760, 560),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
    await show();
    try {
      await trayManager.setIcon('assets/branding/app.ico');
      await trayManager.setToolTip('FlSteamLua');
      _trayAvailable = true;
      await _refreshTray();
    } catch (error) {
      _trayAvailable = false;
      onError?.call(error);
    }
    // Intercept close to finish worker cleanup; hide only when a tray exists.
    await windowManager.setPreventClose(true);
  }

  void _settingsChanged() {
    if (!_initialized || _disposed) return;
    unawaited(_applySettings());
  }

  Future<void> _applySettings() async {
    try {
      if (_trayAvailable) await _refreshTray();
    } catch (error) {
      onError?.call(error);
    }
  }

  Future<void> _refreshTray() => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(
          key: 'show',
          label: localizationsFor(settings.language).openFlsteamlua,
        ),
        if (onRestartSteam != null)
          MenuItem(
            key: 'restart-steam',
            label: localizationsFor(settings.language).restartSteam,
          ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: localizationsFor(settings.language).quit),
      ],
    ),
  );

  Future<void> show() async {
    if (_disposed) return;
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
    onShowRequested?.call();
  }

  @override
  void onWindowClose() {
    if (!_quitting && _trayAvailable && settings.minimizeToTray) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(show());
      case 'restart-steam':
        unawaited(_restartSteam());
      case 'quit':
        unawaited(quit());
    }
  }

  Future<void> _restartSteam() async {
    try {
      await onRestartSteam?.call();
    } catch (error) {
      onError?.call(error);
      await show();
    }
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await onExitRequested?.call();
    } catch (error) {
      _quitting = false;
      onError?.call(error);
      return;
    }
    await dispose();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  Future<void> dispose() async {
    if (!_initialized || _disposed) return;
    _disposed = true;
    settings.removeListener(_settingsChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    if (_trayAvailable) await trayManager.destroy();
    _trayAvailable = false;
  }
}
