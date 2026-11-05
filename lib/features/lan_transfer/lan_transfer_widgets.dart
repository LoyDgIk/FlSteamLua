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
  if (session.status != TransferSessionStatus.transferring ||
      session.speed <= 0 ||
      session.totalBytes <= session.transferredBytes) {
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
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final TransferSession session;
  final SettingsStore settings;
  final Widget? background;
  final Future<void> Function()? onPause;
  final Future<void> Function()? onResume;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return ui.CommonCard(
      inert: true,
      radius: 12,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final artwork = _TransferArtwork(
            session: session,
            settings: settings,
            background: background,
            wide: wide,
          );
          final statistics = _TransferStatistics(
            session: session,
            onPause: onPause,
            onResume: onResume,
            onCancel: onCancel,
          );
          if (wide) {
            return SizedBox(
              height: 270,
              child: Row(
                children: [
                  Expanded(flex: 64, child: artwork),
                  Expanded(flex: 36, child: statistics),
                ],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 180, child: artwork),
              SizedBox(height: 270, child: statistics),
            ],
          );
        },
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

class _TransferArtwork extends StatelessWidget {
  const _TransferArtwork({
    required this.session,
    required this.settings,
    required this.wide,
    this.background,
  });

  final TransferSession session;
  final SettingsStore settings;
  final bool wide;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final surface = context.surfaceLevel.colorOf(scheme);
    final scale = [
      8 * 1024.0,
      ...session.speedSamples,
      ...session.diskSpeedSamples,
    ].reduce(math.max);
    return Stack(
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
              alignment: Alignment.centerLeft,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: scheme.primaryContainer),
            ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: wide ? Alignment.centerLeft : Alignment.topCenter,
              end: wide ? Alignment.centerRight : Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: .16),
                surface.withValues(alpha: .3),
                surface,
              ],
              stops: const [0, .48, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: .72),
                surface.withValues(alpha: 0),
              ],
              stops: const [0, .48],
            ),
          ),
        ),
        Positioned(
          left: -3,
          right: -3,
          bottom: -3,
          height: wide ? 142 : 100,
          child: IgnorePointer(
            child: ui.LineChart(
              values: session.diskSpeedSamples,
              barValues: session.speedSamples,
              revision: session.sampleRevision,
              capacity: lanTransferHistoryCapacity,
              minScale: scale,
              color: scheme.tertiary,
              barColor: scheme.primary.withValues(alpha: .8),
              baselineRatio: 1,
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 18,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.gameName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ui.AppTextStyle.headline
                    .of(context, emphasized: true)
                    .copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 5),
              Text(
                session.message.isEmpty
                    ? TransferHero._statusLabel(context, session.status)
                    : session.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferStatistics extends StatelessWidget {
  const _TransferStatistics({
    required this.session,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final TransferSession session;
  final Future<void> Function()? onPause;
  final Future<void> Function()? onResume;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final resumable =
        session.status == TransferSessionStatus.paused ||
        session.status == TransferSessionStatus.failed;
    final active = switch (session.status) {
      TransferSessionStatus.completed ||
      TransferSessionStatus.failed ||
      TransferSessionStatus.cancelled ||
      TransferSessionStatus.committing => false,
      _ => true,
    };
    final toggle = resumable
        ? onResume
        : session.status == TransferSessionStatus.transferring &&
              session.canPause
        ? onPause
        : null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: context.l10n.lanNetworkTransferred(
                    formatTransferBytes(session.networkBytes),
                  ),
                  child: _SpeedMetric(
                    glyph: ui.AppGlyphs.wifi,
                    label: context.l10n.lanNetworkSpeed,
                    value: formatTransferSpeed(session.speed),
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SpeedMetric(
                  glyph: ui.AppGlyphs.speed,
                  label: context.l10n.lanPeakSpeed,
                  value: formatTransferSpeed(session.peakSpeed),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tooltip(
                  message: formatTransferBytes(session.diskBytes),
                  child: _SpeedMetric(
                    glyph: ui.AppGlyphs.resources,
                    label: context.l10n.lanDiskWriteSpeed,
                    value: formatTransferSpeed(session.diskSpeed),
                    color: scheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _TransferProgress(
            label: session.direction == TransferDirection.receive
                ? context.l10n.lanDownloadProgress
                : context.l10n.lanUploadProgress,
            value:
                '${formatTransferBytes(session.transferredBytes)} / ${formatTransferBytes(session.totalBytes)}',
            progress: session.progress,
            color: scheme.primary,
          ),
          const SizedBox(height: 16),
          Tooltip(
            message:
                '${session.installedFiles}/${session.totalFiles} · ${formatTransferBytes(session.installedBytes)}',
            child: _TransferProgress(
              label: context.l10n.lanInstallProgress,
              value: '${(session.installProgress * 100).round()}%',
              progress: session.installProgress,
              color: scheme.tertiary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.l10n.lanRemainingTime}: ${formatRemaining(session)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ui.AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (onPause != null || onResume != null)
                ui.DashboardIconButton(
                  glyph: session.status == TransferSessionStatus.failed
                      ? ui.AppGlyphs.refresh
                      : ui.AppGlyphs.playPause(resumable ? 0 : 1),
                  tooltip: session.status == TransferSessionStatus.failed
                      ? context.l10n.lanRetryTransfer
                      : resumable
                      ? context.l10n.lanResume
                      : context.l10n.lanPause,
                  selected: true,
                  onPressed: toggle == null
                      ? null
                      : () => _run(context, toggle),
                ),
              if (onCancel != null) ...[
                const SizedBox(width: 4),
                ui.DashboardIconButton(
                  glyph: ui.AppGlyphs.close,
                  tooltip: context.l10n.lanCancelTransfer,
                  onPressed: active ? () => _run(context, onCancel!) : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) ui.showAppError(context, error);
    }
  }
}

class _TransferProgress extends StatelessWidget {
  const _TransferProgress({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ui.AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: ui.AppTextStyle.caption1
                      .of(context, emphasized: true)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ui.CommonProgressBar(value: progress, height: 5, color: color),
    ],
  );
}

class _SpeedMetric extends StatelessWidget {
  const _SpeedMetric({
    required this.glyph,
    required this.label,
    required this.value,
    required this.color,
  });

  final ui.Glyph glyph;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ui.GlyphIcon(glyph, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ui.AppTextStyle.caption2
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: ui.AppTextStyle.subheadline
                .of(context, emphasized: true)
                .copyWith(color: context.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
