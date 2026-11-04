import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../network/network_cover_image.dart';
import 'lan_transfer_models.dart';

String formatTransferBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
  final units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2)} ${units[unit]}';
}

String formatTransferSpeed(num bytesPerSecond) =>
    '${formatTransferBytes(bytesPerSecond)}/s';

String formatRemaining(TransferSession session) {
  if (session.speed <= 0 || session.totalBytes <= session.transferredBytes) {
    return '--';
  }
  final seconds =
      (session.totalBytes - session.transferredBytes) / session.speed;
  final duration = Duration(seconds: seconds.ceil());
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

class TransferHero extends StatelessWidget {
  const TransferHero({
    super.key,
    required this.session,
    required this.settings,
    this.background,
  });

  final TransferSession session;
  final SettingsStore settings;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final peak = math.max(session.peakSpeed, 1);
    final samples = session.speedSamples.isEmpty
        ? const [0.0]
        : [
            for (final sample in session.speedSamples)
              (sample / peak).clamp(0.03, 1.0),
          ];
    return ui.CommonCard(
      inert: true,
      radius: 24,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 270,
        child: Stack(
          fit: StackFit.expand,
          children: [
            background ??
                NetworkCoverImage(
                  settings: settings,
                  appId: session.appId,
                  url:
                      session.coverUrl ??
                      'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/${session.appId}/header.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: scheme.primaryContainer),
                ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0xCC10141A),
                    Color(0xF010141A),
                  ],
                  stops: [0, .5, 1],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 118,
              child: IgnorePointer(
                child: ui.LineChart(
                  values: samples,
                  revision: DateTime.now().microsecondsSinceEpoch,
                  capacity: 72,
                  minScale: .04,
                  color: const Color(0xFF8CD867),
                  baselineRatio: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SpeedMetric(
                        glyph: ui.AppGlyphs.wifi,
                        label: context.l10n.lanNetworkSpeed,
                        value: formatTransferSpeed(session.speed),
                      ),
                      const SizedBox(width: 24),
                      _SpeedMetric(
                        glyph: ui.AppGlyphs.speed,
                        label: context.l10n.lanPeakSpeed,
                        value: formatTransferSpeed(session.peakSpeed),
                      ),
                      const Spacer(),
                      ui.TonalChip(
                        label: _statusLabel(context, session.status),
                        color: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    session.gameName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui.AppTextStyle.title2
                        .of(context, emphasized: true)
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatTransferBytes(session.transferredBytes)} / ${formatTransferBytes(session.totalBytes)}',
                    style: ui.AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  ui.CommonProgressBar(value: session.progress, height: 5),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.message.isNotEmpty
                              ? session.message
                              : session.status ==
                                    TransferSessionStatus.waitingForSteamExit
                              ? context.l10n.lanWaitingSteam
                              : session.status ==
                                    TransferSessionStatus.waitingForApproval
                              ? context.l10n.lanWaitingApproval
                              : session.status ==
                                    TransferSessionStatus.verifying
                              ? context.l10n.lanVerifying
                              : session.status ==
                                    TransferSessionStatus.committing
                              ? context.l10n.lanCommitting
                              : context.l10n.lanProgress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ui.AppTextStyle.caption1
                              .of(context)
                              .copyWith(color: Colors.white70),
                        ),
                      ),
                      Text(
                        '${context.l10n.lanRemainingTime}: ${formatRemaining(session)}',
                        style: ui.AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(
    BuildContext context,
    TransferSessionStatus status,
  ) => switch (status) {
    TransferSessionStatus.preparing => context.l10n.lanPreparing,
    TransferSessionStatus.waitingForApproval => context.l10n.lanWaitingApproval,
    TransferSessionStatus.transferring => context.l10n.lanProgress,
    TransferSessionStatus.paused => context.l10n.lanPaused,
    TransferSessionStatus.verifying => context.l10n.lanVerifying,
    TransferSessionStatus.waitingForSteamExit => context.l10n.lanWaitingSteam,
    TransferSessionStatus.committing => context.l10n.lanCommitting,
    TransferSessionStatus.completed => context.l10n.lanCompleted,
    TransferSessionStatus.failed => context.l10n.lanFailed,
    TransferSessionStatus.cancelled => context.l10n.lanCancelled,
  };
}

class _SpeedMetric extends StatelessWidget {
  const _SpeedMetric({
    required this.glyph,
    required this.label,
    required this.value,
  });

  final ui.Glyph glyph;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ui.GlyphIcon(glyph, size: 18, color: Colors.white70),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ui.AppTextStyle.caption2
                  .of(context)
                  .copyWith(color: Colors.white60),
            ),
            Text(
              value,
              style: ui.AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}
