import 'package:flutter/material.dart';

import '../core/task_center.dart';
import '../ui/context.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;

class TaskPanel extends StatelessWidget {
  const TaskPanel({
    super.key,
    required this.tasks,
    this.onTaskPressed,
    this.onCancelTask,
  });

  final TaskCenter tasks;
  final void Function(TaskProgress task)? onTaskPressed;
  final void Function(TaskProgress task)? onCancelTask;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) => ui.SideSheetScaffold(
      title: context.l10n.tasks,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.clearCompleted,
          onPressed:
              tasks.tasks.any((task) => task.status != TaskStatus.running)
              ? tasks.clearCompleted
              : null,
          icon: const ui.GlyphIcon(ui.AppGlyphs.clearAll, size: 24),
        ),
      ],
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ui.NullStatusSwitcher(
          isEmpty: tasks.tasks.isEmpty,
          nullStatus: ui.NullStatus(
            label: context.l10n.allClear,
            description: context.l10n.downloadsImportsAndBackupsWillAppearHere,
            illustration: ui.NullStatusIllustration.data,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: tasks.tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks.tasks[index];
              final open = onTaskPressed != null && task.actionId != null
                  ? () {
                      Navigator.of(context).pop();
                      onTaskPressed!(task);
                    }
                  : null;
              return _TaskCard(
                task: task,
                tasks: tasks,
                onPressed: open,
                onCancel: onCancelTask == null
                    ? null
                    : () {
                        tasks.cancel(task.id);
                        onCancelTask!(task);
                      },
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.tasks,
    this.onPressed,
    this.onCancel,
  });

  final TaskProgress task;
  final TaskCenter tasks;
  final VoidCallback? onPressed;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final running = task.status == TaskStatus.running;
    final progress = task.progress?.clamp(0.0, 1.0);
    final percent = progress == null ? null : (progress * 100).round();
    final color = switch (task.status) {
      TaskStatus.failed => context.colorScheme.error,
      TaskStatus.succeeded => context.colorScheme.primary,
      _ => context.colorScheme.onSurfaceVariant,
    };
    return ui.CommonCard(
      radius: 20,
      inert: onPressed == null,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ui.GlyphIcon(
                  switch (task.status) {
                    TaskStatus.succeeded => ui.AppGlyphs.checkCircle,
                    TaskStatus.failed => ui.AppGlyphs.error,
                    TaskStatus.cancelled => ui.AppGlyphs.block,
                    _ => ui.AppGlyphs.cloudDownload,
                  },
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui.AppTextStyle.subheadline.of(
                      context,
                      emphasized: true,
                    ),
                  ),
                ),
                if (running)
                  IconButton(
                    onPressed: task.cancellationRequested
                        ? null
                        : onCancel ?? () => tasks.cancel(task.id),
                    tooltip: context.l10n.cancel,
                    icon: const ui.GlyphIcon(ui.AppGlyphs.close, size: 18),
                  ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 10),
              Semantics(
                value: percent == null ? null : '$percent%',
                child: ui.CommonProgressBar(
                  key: ValueKey('task-progress-${task.id}'),
                  value: task.progress,
                  height: 6,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.error?.toString() ??
                        (task.cancellationRequested && running
                            ? context.l10n.cancelling
                            : task.message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ui.AppTextStyle.caption1
                        .of(context)
                        .copyWith(
                          color: task.status == TaskStatus.failed
                              ? color
                              : context.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (running && percent != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: ui.AppTextStyle.caption1
                        .of(context, emphasized: true)
                        .copyWith(color: context.colorScheme.primary),
                  ),
                ],
              ],
            ),
            if (task.logs.isNotEmpty)
              ui.CollapsibleSection(
                label: context.l10n.showLogs,
                itemCount: 1,
                showCount: false,
                initiallyExpanded: false,
                headerStyle: ui.AppTextStyle.caption1.of(
                  context,
                  emphasized: true,
                ),
                itemBuilder: (context, _) => SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: context.raisedSurfaceLevel.colorOf(
                          context.colorScheme,
                        ),
                        shape: ui.AppShape.md,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: SelectionArea(
                          child: Text(
                            task.logs.join('\n'),
                            style: ui.AppTextStyle.caption1
                                .of(context)
                                .copyWith(
                                  fontFamily: 'Consolas',
                                  height: 1.5,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
