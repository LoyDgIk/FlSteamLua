import 'dart:io';
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_widgets.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? fontFamily;
  String? chineseFontFamily;
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (!await font.exists()) return;
    final loader = FontLoader('LanCapture')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
    fontFamily = 'LanCapture';
    final chineseFont = File(r'C:\Windows\Fonts\msyh.ttc');
    if (await chineseFont.exists()) {
      await (FontLoader('LanCaptureChinese')..addFont(
            Future.value(ByteData.sublistView(await chineseFont.readAsBytes())),
          ))
          .load();
      chineseFontFamily = 'LanCaptureChinese';
    }
  });
  TransferSession session({
    TransferSessionStatus status = TransferSessionStatus.transferring,
  }) => TransferSession(
    id: 'send:fixture',
    bundleId: 'fixture',
    appId: 42,
    gameName: 'Fixture Game',
    direction: TransferDirection.send,
    peer: const LanPeer(
      id: 'peer',
      alias: 'Peer',
      address: '127.0.0.1',
      port: lanTransferPort,
      fingerprint: '00',
      trusted: true,
    ),
    status: status,
    totalBytes: 100 * 1024 * 1024,
    transferredBytes: 48 * 1024 * 1024,
    networkBytes: 24 * 1024 * 1024,
    diskBytes: 24 * 1024 * 1024,
    diskSpeed: 6 * 1024 * 1024,
    installedBytes: 18 * 1024 * 1024,
    installedFiles: 41,
    totalFiles: 50,
    canPause: true,
    speed: 12 * 1024 * 1024,
    peakSpeed: 20 * 1024 * 1024,
    createdAt: DateTime.now(),
    speedSamples: const [
      2e6,
      4e6,
      1e6,
      8e6,
      6e6,
      9e6,
      12e6,
      8e6,
      4e6,
      7e6,
      10e6,
      8e6,
      6e6,
      5e6,
      4e6,
      8e6,
      11e6,
      12e6,
    ],
    diskSpeedSamples: const [
      1e6,
      3e6,
      2e6,
      6e6,
      4e6,
      7e6,
      8e6,
      6e6,
      3e6,
      5e6,
      9e6,
      6e6,
      4e6,
      3e6,
      2e6,
      5e6,
      7e6,
      6e6,
    ],
    sampleRevision: 18,
  );

  testWidgets('wide card uses reported network, disk and install progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsStore(AppPaths('fixture'));
    addTearDown(settings.dispose);
    final transfer = session();
    final capture = GlobalKey();
    var paused = false;
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          fontFamily: fontFamily,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: capture,
              child: SizedBox(
                width: 1440,
                child: TransferHero(
                  session: transfer,
                  settings: settings,
                  onPause: () async => paused = true,
                  onResume: () async {},
                  onCancel: () async => cancelled = true,
                  background: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff965b37), Color(0xff263e56)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Fixture Game'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Peak'), findsOneWidget);
    expect(find.text('12.0 MB/s'), findsOneWidget);
    expect(find.text('Disk writes'), findsOneWidget);
    expect(find.text('6.00 MB/s'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    final progress = tester
        .widgetList<ui.CommonProgressBar>(find.byType(ui.CommonProgressBar))
        .toList();
    expect(progress.map((bar) => bar.value), [.48, .82]);
    final chart = tester.widget<ui.LineChart>(find.byType(ui.LineChart));
    expect(chart.barValues, transfer.speedSamples);
    expect(chart.values, transfer.diskSpeedSamples);
    expect(chart.revision, 18);
    expect(tester.getSize(find.byType(TransferHero)).height, 270);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Pause transfer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel transfer'));
    await tester.pump();
    expect(paused, isTrue);
    expect(cancelled, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, capture, 'transfer_hero_wide_dark.png');
  });

  for (final width in [320.0, 640.0]) {
    testWidgets('narrow card fits at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsStore(AppPaths('fixture'));
      addTearDown(settings.dispose);
      final capture = GlobalKey();
      var resumed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(
            seedColor: Colors.teal,
            fontFamily: fontFamily,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: width,
                  child: TransferHero(
                    session: session(status: TransferSessionStatus.paused),
                    settings: settings,
                    background: const ColoredBox(color: Color(0xffb7dbd3)),
                    onResume: () async => resumed = true,
                    onCancel: () async {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(TransferHero)).height, 450);
      expect(tester.takeException(), isNull);
      expect(find.text('Time remaining: --'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume transfer'));
      await tester.pump();
      expect(resumed, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(
        tester,
        capture,
        'transfer_hero_narrow_${width.round()}.png',
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Chinese ${brightness.name} card preview uses theme colors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1500, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsStore(AppPaths('fixture'));
      addTearDown(settings.dispose);
      final transfer = session();
      final network = List.of(transfer.speedSamples);
      final disk = List.of(transfer.diskSpeedSamples);
      transfer.speedSamples
        ..clear()
        ..addAll(List.generate(72, (index) => network[index % network.length]));
      transfer.diskSpeedSamples
        ..clear()
        ..addAll(List.generate(72, (index) => disk[index % disk.length]));
      transfer.sampleRevision = 72;
      final capture = GlobalKey();
      final theme = ui.buildAppTheme(
        seedColor: Colors.blue,
        brightness: brightness,
        fontFamily: chineseFontFamily ?? fontFamily,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: 1440,
                  child: TransferHero(
                    session: transfer,
                    settings: settings,
                    onPause: () async {},
                    onResume: () async {},
                    onCancel: () async {},
                    background: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff965b37), Color(0xff263e56)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('磁盘写入'), findsOneWidget);
      expect(find.text('正在安装文件'), findsOneWidget);
      final chart = tester.widget<ui.LineChart>(find.byType(ui.LineChart));
      expect(chart.color, theme.colorScheme.tertiary);
      expect(chart.barColor, theme.colorScheme.primary.withValues(alpha: .8));
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        capture,
        'transfer_hero_wide_zh_${brightness.name}.png',
      );
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const captureRoot = String.fromEnvironment('LAN_CARD_CAPTURE_DIR');
  if (captureRoot.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: dart_ui.ImageByteFormat.png);
    await Directory(captureRoot).create(recursive: true);
    await File('$captureRoot/$name').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
