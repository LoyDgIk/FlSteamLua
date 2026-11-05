// Sorting layout adapted from FlClash's ReorderableProfilesSheet at
// 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'lua_directories.dart';

class LuaDirectoriesPage extends StatefulWidget {
  const LuaDirectoriesPage({
    super.key,
    required this.steamPath,
    required this.onSaved,
  });

  final String steamPath;
  final Future<void> Function() onSaved;

  @override
  State<LuaDirectoriesPage> createState() => _LuaDirectoriesPageState();
}

class _LuaDirectoriesPageState extends State<LuaDirectoriesPage> {
  late final _config = LuaDirectories(widget.steamPath);
  List<String> _paths = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    try {
      _paths = List.of(_config.customPaths());
    } catch (error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ui.showAppError(context, error);
      });
    }
  }

  Future<void> _edit([int? index]) => ui.showFormSheet<void>(
    context: context,
    builder: (_) => _LuaDirectoryForm(
      title: index == null ? context.l10n.addLuaDirectory : context.l10n.edit,
      value: index == null ? '' : _paths[index],
      hint: _config.coreDefault,
      onSave: (path) async {
        if (LuaDirectories.samePath(path, _config.coreDefault) ||
            _paths.indexed.any(
              (entry) =>
                  entry.$1 != index && LuaDirectories.samePath(entry.$2, path),
            )) {
          throw FormatException(context.l10n.luaDirectoryAlreadyAdded);
        }
        final next = [..._paths];
        if (index == null) {
          next.add(path);
        } else {
          next[index] = path;
        }
        await _persist(next);
      },
    ),
  );

  Future<void> _persist(List<String> next) async {
    setState(() => _saving = true);
    try {
      await _config.save(next);
      if (mounted) setState(() => _paths = List.of(_config.customPaths()));
      await widget.onSaved();
      if (mounted) ui.showAppSuccess(context, context.l10n.luaDirectoriesSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(int index) async {
    final path = _paths[index];
    try {
      await _persist([..._paths]..removeAt(index));
      if (!mounted) return;
      ui.showAppFeedback(
        context,
        context.l10n.luaDirectoryRemoved,
        actionState: ui.MessageActionState(
          actionText: context.l10n.undo,
          action: () async {
            try {
              final next = [..._paths];
              next.insert(index.clamp(0, next.length), path);
              await _persist(next);
            } catch (error) {
              if (mounted) ui.showAppError(context, error);
            }
          },
        ),
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Widget _row(int index) => ui.DecorationListItem(
    key: ValueKey(_paths[index]),
    title: Text(_paths[index]),
    subtitle: index == 0 ? Text(context.l10n.defaultLuaWriteDirectory) : null,
    onPressed: _saving ? null : () => _edit(index),
    trailing: ui.CommonPopupBox(
      targetBuilder: (open) => IconButton(
        tooltip: context.l10n.manage,
        onPressed: _saving ? null : open,
        icon: const ui.GlyphIcon(ui.AppGlyphs.more),
      ),
      popupBuilder: (_) => ui.CommonPopupMenu(
        items: [
          ui.CommonPopupMenuItem(
            label: context.l10n.edit,
            onPressed: () => _edit(index),
          ),
          ui.CommonPopupMenuItem(
            label: context.l10n.remove,
            onPressed: () => _remove(index),
          ),
        ],
      ),
    ),
  );

  Future<void> _showSort() async {
    final sorted = await ui.showModalSideSheet<List<String>>(
      context: context,
      builder: (_) => _LuaDirectorySortSheet(initial: _paths),
    );
    if (sorted == null || !mounted) return;
    try {
      await _persist(sorted);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.luaDirectories,
    isLoading: _saving,
    actions: [
      IconButton(
        key: const ValueKey('add-lua-directory'),
        tooltip: context.l10n.addLuaDirectory,
        onPressed: _saving ? null : () => _edit(),
        icon: const ui.GlyphIcon(ui.AppGlyphs.add),
      ),
      IconButton(
        key: const ValueKey('sort-lua-directories'),
        tooltip: context.l10n.sort,
        onPressed: _saving || _paths.length < 2 ? null : _showSort,
        icon: const ui.GlyphIcon(ui.AppGlyphs.sort),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, ui.pageContentTopInset, 16, 32),
      children: [
        ui.generateSection(
          title: context.l10n.coreLuaDirectory,
          items: [
            ui.DecorationListItem(
              key: const ValueKey('core-lua-directory'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.code),
              title: Text(_config.coreDefault),
              subtitle: _paths.isEmpty
                  ? Text(context.l10n.defaultLuaWriteDirectory)
                  : null,
            ),
          ],
        ),
        ui.ListHeader(title: context.l10n.customLuaDirectories),
        ui.AnimatedEntries(
          grouped: true,
          children: [for (var i = 0; i < _paths.length; i++) _row(i)],
        ),
        if (_paths.isEmpty)
          ui.NullStatus(
            label: context.l10n.noCustomLuaDirectories,
            illustration: ui.NullStatusIllustration.data,
          ),
      ],
    ),
  );
}

class _LuaDirectorySortSheet extends StatefulWidget {
  const _LuaDirectorySortSheet({required this.initial});
  final List<String> initial;
  @override
  State<_LuaDirectorySortSheet> createState() => _LuaDirectorySortSheetState();
}

class _LuaDirectorySortSheetState extends State<_LuaDirectorySortSheet> {
  late final _paths = List<String>.of(widget.initial);

  Widget _row(int index) => ReorderableDelayedDragStartListener(
    key: ValueKey(_paths[index]),
    index: index,
    child: ui.ItemPositionProvider(
      position: ui.ItemPosition.get(index, _paths.length),
      child: ui.DecorationListItem(
        title: Text(_paths[index]),
        subtitle: index == 0
            ? Text(context.l10n.defaultLuaWriteDirectory)
            : null,
        trailing: ui.SortHandle(index: index),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.luaDirectoriesSort,
    actions: [
      ui.SideSheetHeaderButton(
        key: const ValueKey('save-lua-directory-order'),
        tooltip: context.l10n.save,
        icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
        onPressed: () => Navigator.of(context).pop(_paths),
      ),
    ],
    body: ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.fromLTRB(
        16,
        ui.SideSheetScaffold.headerHeight + 16,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      proxyDecorator: (child, index, animation) =>
          ui.commonProxyDecorator(_row(index), index, animation),
      onReorderItem: (oldIndex, newIndex) =>
          setState(() => _paths.insert(newIndex, _paths.removeAt(oldIndex))),
      itemBuilder: (_, index) => _row(index),
      itemCount: _paths.length,
    ),
  );
}

class _LuaDirectoryForm extends StatefulWidget {
  const _LuaDirectoryForm({
    required this.title,
    required this.value,
    required this.hint,
    required this.onSave,
  });
  final String title, value, hint;
  final Future<void> Function(String) onSave;
  @override
  State<_LuaDirectoryForm> createState() => _LuaDirectoryFormState();
}

class _LuaDirectoryFormState extends State<_LuaDirectoryForm> {
  late final _controller = TextEditingController(text: widget.value);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      setState(() => _error = context.l10n.requiredField);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(path);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: widget.title,
    saving: _saving,
    error: _error,
    onSave: _save,
    children: [
      ui.generateSection(
        items: [
          ui.FormRow(
            title: context.l10n.luaFolder,
            trailing: ui.FormRowTextField(
              key: const ValueKey('lua-directory-input'),
              controller: _controller,
              enabled: !_saving,
              hintText: widget.hint,
            ),
          ),
          ui.DecorationListItem(
            leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
            title: Text(context.l10n.chooseAFolder),
            onPressed: _saving
                ? null
                : () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null && mounted) {
                      setState(() => _controller.text = path);
                    }
                  },
          ),
        ],
      ),
    ],
  );
}
