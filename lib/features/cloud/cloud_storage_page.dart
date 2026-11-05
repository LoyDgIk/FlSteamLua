import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import 'cloud_service.dart';
import 'cloud_storage_form.dart';
import 'cloud_workflows.dart';

class CloudStoragePage extends StatefulWidget {
  const CloudStoragePage({
    super.key,
    required this.service,
    this.appId,
    this.tasks,
    this.steam,
  });
  final CloudService service;
  final int? appId;
  final TaskCenter? tasks;
  final SteamProcessActions? steam;
  @override
  State<CloudStoragePage> createState() => _CloudStoragePageState();
}

class _CloudStoragePageState extends State<CloudStoragePage> {
  bool _busy = false;
  CloudService get service => widget.service;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _edit([CloudStorageProfile? profile, bool copy = false]) async {
    try {
      final values = profile == null
          ? <String, dynamic>{}
          : await service.storageValues(profile.id);
      if (!mounted) return;
      final saved = await ui.showFormSheet<bool>(
        context: context,
        builder: (_) => CloudStorageForm(
          service: service,
          profileId: copy ? null : profile?.id,
          initialProvider: profile?.provider ?? 'folder',
          initialValues: values,
          initialName: profile?.name ?? '',
        ),
      );
      if (saved == true && mounted) {
        ui.showAppSuccess(context, context.l10n.cloudStorageSaved);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _move(CloudStorageProfile profile) async {
    final destination = await FilePicker.platform.getDirectoryPath();
    if (destination == null || !mounted) return;
    try {
      if (!await confirmCloudOperation(
        context,
        title: context.l10n.changeSaveFolder,
        steam: widget.steam,
        stopSteam: true,
        explanation: context
            .l10n
            .closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd,
        details: [
          (profile.name, profile.folder),
          (context.l10n.cloudDestination, destination),
        ],
      )) {
        return;
      }
      if (!mounted) return;
      await runCloudOperation(
        context,
        service,
        title: context.l10n.changeSaveFolder,
        tasks: widget.tasks,
        mutation: false,
        action: (task) => service.moveActiveFolder(destination, context: task),
        success: context.l10n.cloudStorageActivated,
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _action(String action, CloudStorageProfile profile) async {
    if (action == 'edit' || action == 'copy') {
      await _edit(profile, action == 'copy');
      return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'browse') {
        await service.browseStorage(profile.id, appId: widget.appId);
        if (mounted) Navigator.of(context).pop(true);
      } else if (action == 'activate') {
        if (!await confirmCloudOperation(
          context,
          title: context.l10n.cloudActivate,
          explanation: context.l10n.cloudStorageActivated,
          details: [(profile.name, profile.summary)],
        )) {
          return;
        }
        await service.activateStorage(profile.id);
        if (mounted) {
          ui.showAppSuccess(context, context.l10n.cloudStorageActivated);
        }
      } else if (action == 'remove' || action == 'disconnect') {
        if (!await confirmCloudOperation(
          context,
          title: action == 'remove'
              ? context.l10n.delete
              : context.l10n.disconnect,
          details: [(profile.name, profile.summary)],
          explanation: action == 'remove'
              ? context.l10n.cloudStorageRemoved
              : context.l10n.cloudDisconnectConfirm,
        )) {
          return;
        }
        if (action == 'remove') {
          await service.removeStorage(profile.id);
        } else {
          await service.disconnectStorage(profile.id);
        }
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sort() async {
    final order = await ui.showModalSideSheet<List<String>>(
      context: context,
      builder: (_) => _StorageSortSheet(profiles: service.savedStorageProfiles),
    );
    if (order == null) return;
    try {
      await service.reorderStorages(order);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || service.busy;
    return ui.CommonScaffold(
      title: context.l10n.cloudStorages,
      isLoading: _busy,
      actions: [
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.add,
          tooltip: context.l10n.cloudAddStorage,
          onPressed: disabled ? null : () => _edit(),
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.sort,
          tooltip: context.l10n.cloudSortStorages,
          onPressed: disabled || service.savedStorageProfiles.length < 2
              ? null
              : _sort,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, ui.pageContentTopInset, 16, 24),
        children: [
          ui.AnimatedEntries(
            grouped: true,
            children: [
              for (final profile in service.storageProfiles)
                ui.DecorationListItem(
                  key: ValueKey(profile.id),
                  leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${cloudProviderName(context, profile.provider)} · ${profile.summary}\n${profile.checkedAt == null ? context.l10n.cloudNotTested : '${profile.writeTested ? context.l10n.cloudWriteVerified : context.l10n.cloudReadVerified} · ${profile.checkedAt!.toLocal()}'}',
                  ),
                  onPressed: disabled ? null : () => _edit(profile),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (profile.id == service.activeStorageId)
                        ui.MetaChip(label: context.l10n.cloudActiveTarget),
                      ui.CommonPopupBox(
                        targetBuilder: (open) => IconButton(
                          tooltip: context.l10n.manage,
                          onPressed: disabled ? null : open,
                          icon: const ui.GlyphIcon(ui.AppGlyphs.more),
                        ),
                        popupBuilder: (_) => ui.CommonPopupMenu(
                          items: [
                            ui.CommonPopupMenuItem(
                              label: context.l10n.cloudBrowse,
                              glyph: ui.AppGlyphs.resources,
                              onPressed: () => _action('browse', profile),
                            ),
                            if (profile.id != service.activeStorageId)
                              ui.CommonPopupMenuItem(
                                label: context.l10n.cloudActivate,
                                glyph: ui.AppGlyphs.checkCircle,
                                onPressed: () => _action('activate', profile),
                              ),
                            ui.CommonPopupMenuItem(
                              label: context.l10n.edit,
                              glyph: ui.AppGlyphs.edit,
                              onPressed: () => _action('edit', profile),
                            ),
                            if (profile.provider == 'folder' &&
                                profile.id == service.activeStorageId)
                              ui.CommonPopupMenuItem(
                                label: context.l10n.changeSaveFolder,
                                glyph: ui.AppGlyphs.resources,
                                onPressed: () => _move(profile),
                              ),
                            ui.CommonPopupMenuItem(
                              label: context.l10n.cloudDuplicate,
                              glyph: ui.AppGlyphs.copy,
                              onPressed: () => _action('copy', profile),
                            ),
                            if (profile.provider != 'folder')
                              ui.CommonPopupMenuItem(
                                label: context.l10n.disconnect,
                                glyph: ui.AppGlyphs.close,
                                onPressed: () => _action('disconnect', profile),
                              ),
                            if (profile.id != service.activeStorageId)
                              ui.CommonPopupMenuItem(
                                label: context.l10n.delete,
                                glyph: ui.AppGlyphs.delete,
                                danger: true,
                                onPressed: () => _action('remove', profile),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Adapter of FlClash ReorderableProfilesSheet and the shared Lua directory sheet.
class _StorageSortSheet extends StatefulWidget {
  const _StorageSortSheet({required this.profiles});
  final List<CloudStorageProfile> profiles;
  @override
  State<_StorageSortSheet> createState() => _StorageSortSheetState();
}

class _StorageSortSheetState extends State<_StorageSortSheet> {
  late final _profiles = [...widget.profiles];
  Widget _row(int index) => ReorderableDelayedDragStartListener(
    key: ValueKey(_profiles[index].id),
    index: index,
    child: ui.ItemPositionProvider(
      position: ui.ItemPosition.get(index, _profiles.length),
      child: ui.DecorationListItem(
        title: Text(_profiles[index].name),
        subtitle: Text(_profiles[index].summary),
        trailing: ui.SortHandle(index: index),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.cloudSortStorages,
    actions: [
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.save,
        icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
        onPressed: () =>
            Navigator.of(context).pop(_profiles.map((v) => v.id).toList()),
      ),
    ],
    body: ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        ui.SideSheetScaffold.headerHeight + 16,
        16,
        24,
      ),
      buildDefaultDragHandles: false,
      itemCount: _profiles.length,
      itemBuilder: (_, i) => _row(i),
      proxyDecorator: (child, index, animation) =>
          ui.commonProxyDecorator(_row(index), index, animation),
      onReorderItem: (oldIndex, newIndex) => setState(
        () => _profiles.insert(newIndex, _profiles.removeAt(oldIndex)),
      ),
    ),
  );
}
