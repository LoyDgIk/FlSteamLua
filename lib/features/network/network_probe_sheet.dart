import 'package:flutter/material.dart';

import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'network_preferences.dart';

enum NetworkProbeKind { covers, mirrors }

Future<void> showCoverProbeSheet({
  required BuildContext context,
  required NetworkPreferences preferences,
  required TaskCenter tasks,
}) => _showProbeSheet(
  context: context,
  preferences: preferences,
  tasks: tasks,
  kind: NetworkProbeKind.covers,
);

Future<void> showMirrorProbeSheet({
  required BuildContext context,
  required NetworkPreferences preferences,
  required TaskCenter tasks,
}) => _showProbeSheet(
  context: context,
  preferences: preferences,
  tasks: tasks,
  kind: NetworkProbeKind.mirrors,
);

Future<void> _showProbeSheet({
  required BuildContext context,
  required NetworkPreferences preferences,
  required TaskCenter tasks,
  required NetworkProbeKind kind,
}) => ui.showModalSideSheet<void>(
  context: context,
  builder: (_) =>
      NetworkProbeSheet(preferences: preferences, tasks: tasks, kind: kind),
);

class NetworkProbeSheet extends StatefulWidget {
  const NetworkProbeSheet({
    super.key,
    required this.preferences,
    required this.tasks,
    required this.kind,
  });

  final NetworkPreferences preferences;
  final TaskCenter tasks;
  final NetworkProbeKind kind;

  @override
  State<NetworkProbeSheet> createState() => _NetworkProbeSheetState();
}

class _NetworkProbeSheetState extends State<NetworkProbeSheet> {
  final _results = <String, NetworkProbeResult>{};
  final _probing = <String>{};

  List<_ProbeTarget> get _targets => switch (widget.kind) {
    NetworkProbeKind.covers => [
      for (final source in NetworkPreferences.coverSources)
        if (source.id != 'auto')
          _ProbeTarget(
            id: source.id,
            label: source.label(context.l10n),
            selected: widget.preferences.coverSourceId == source.id,
          ),
    ],
    NetworkProbeKind.mirrors => [
      for (final host in widget.preferences.mirrorTargets)
        _ProbeTarget(
          id: host,
          label: host == 'direct'
              ? context.l10n.directGithub
              : host == NetworkPreferences.customMirrorId
              ? context.l10n.customGithubMirror
              : host,
          selected: widget.preferences.mirrorSelection == host,
        ),
    ],
  };

  String get _title => switch (widget.kind) {
    NetworkProbeKind.covers => context.l10n.testCoverSources,
    NetworkProbeKind.mirrors => context.l10n.testPublicDownloadSources,
  };

  String get _footer => switch (widget.kind) {
    NetworkProbeKind.covers =>
      context
          .l10n
          .byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea,
    NetworkProbeKind.mirrors =>
      context
          .l10n
          .mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin,
  };

  ui.Glyph get _glyph => switch (widget.kind) {
    NetworkProbeKind.covers => ui.AppGlyphs.photos,
    NetworkProbeKind.mirrors => ui.AppGlyphs.cloudDownload,
  };

  Future<void> _testAll() async {
    if (_probing.isNotEmpty) return;
    final targets = _targets;
    setState(() => _probing.addAll(targets.map((target) => target.id)));
    try {
      final results = await widget.tasks.run(
        _title,
        (task) => switch (widget.kind) {
          NetworkProbeKind.covers => widget.preferences.testCovers(task: task),
          NetworkProbeKind.mirrors => widget.preferences.testMirrors(
            task: task,
          ),
        },
      );
      if (mounted) {
        setState(() {
          for (final result in results) {
            _results[result.sourceId] = result;
          }
        });
      }
    } on TaskCancelled {
      if (mounted) {
        ui.showAppFeedback(context, context.l10n.testCancelled);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(_probing.clear);
    }
  }

  Future<void> _testOne(_ProbeTarget target) async {
    if (_probing.contains(target.id)) return;
    setState(() => _probing.add(target.id));
    try {
      final result = await widget.tasks.run(
        _title,
        (task) => switch (widget.kind) {
          NetworkProbeKind.covers => widget.preferences.testCoverSource(
            target.id,
            task: task,
          ),
          NetworkProbeKind.mirrors => widget.preferences.testMirror(
            target.id,
            task: task,
          ),
        },
      );
      if (mounted) setState(() => _results[target.id] = result);
    } on TaskCancelled {
      if (mounted) {
        ui.showAppFeedback(context, context.l10n.testCancelled);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _probing.remove(target.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    return ui.SideSheetScaffold(
      title: _title,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: _title,
          onPressed: _probing.isEmpty ? _testAll : null,
          icon: _probing.length == targets.length
              ? const SizedBox.square(
                  dimension: 18,
                  child: ui.CommonCircleLoading(size: 18),
                )
              : const ui.GlyphIcon(ui.AppGlyphs.speed, size: 24),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateGroup([
            for (final target in targets)
              ui.DecorationListItem(
                key: ValueKey('network-probe-${target.id}'),
                leading: ui.GlyphIcon(_glyph, size: 20),
                title: Text(target.label),
                subtitle: switch (_results[target.id]) {
                  NetworkProbeResult(error: final error?) => Text(error),
                  _ => null,
                },
                isSelected: target.selected,
                onPressed: _probing.contains(target.id)
                    ? null
                    : () => _testOne(target),
                trailing: _trailing(context, target.id),
              ),
          ]),
          ui.ListFooter(text: _footer),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context, String sourceId) {
    if (_probing.contains(sourceId)) {
      return const SizedBox.square(
        dimension: 16,
        child: ui.CommonCircleLoading(size: 16),
      );
    }
    final result = _results[sourceId];
    if (result == null) {
      return Text(
        context.l10n.pending,
        style: ui.AppTextStyle.caption1
            .of(context)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      );
    }
    if (!result.succeeded) {
      return Text(
        context.l10n.failed,
        style: ui.AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(color: context.colorScheme.error),
      );
    }
    return Text(
      '${result.elapsed!.inMilliseconds} ms',
      style: ui.AppTextStyle.caption1
          .of(context, emphasized: true)
          .copyWith(color: context.colorScheme.primary),
    );
  }
}

class _ProbeTarget {
  const _ProbeTarget({
    required this.id,
    required this.label,
    required this.selected,
  });

  final String id;
  final String label;
  final bool selected;
}
