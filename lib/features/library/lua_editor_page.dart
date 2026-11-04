import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/game_entry.dart';
import '../../ui/ui.dart' as ui;
import 'library_service.dart';
import '../../ui/localization.dart';

class LuaEditorPage extends StatefulWidget {
  const LuaEditorPage({super.key, required this.library, required this.game});

  final LibraryService library;
  final GameEntry game;

  @override
  State<LuaEditorPage> createState() => _LuaEditorPageState();
}

class _LuaEditorPageState extends State<LuaEditorPage> {
  final _editor = TextEditingController();
  final _focus = FocusNode();
  String _saved = '';
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _loaded = false;
  bool _allowPop = false;
  bool get _dirty => _editor.text != _saved;

  @override
  void initState() {
    super.initState();
    _editor.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final text = await widget.library.readLua(widget.game.appId);
      if (!mounted) return;
      _saved = text;
      _editor.text = text;
      setState(() {
        _loading = false;
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _save() async {
    final localeText = context.l10n;
    if (_loading || _saving || !_dirty || !_loaded) return;
    setState(() => _saving = true);
    final text = _editor.text;
    try {
      await widget.library.saveLua(widget.game.appId, text);
      if (!mounted) return;
      setState(() {
        _saved = text;
        _error = null;
      });
      ui.showAppSuccess(context, localeText.luaSavedTheOriginalWasBackedUp);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    final localeText = context.l10n;
    if (_saving) return;
    if (_dirty) {
      final discard = await ui.showFlDialog<bool>(
        context: context,
        builder: (context) => ui.CommonDialog(
          title: localeText.discardUnsavedChanges,
          destructive: true,
          actions: [
            ui.CommonDialogAction(
              label: localeText.keepEditing,
              onPressed: () => Navigator.pop(context, false),
            ),
            ui.CommonDialogAction(
              label: localeText.discard,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          child: Text(localeText.theseChangesHaveNotBeenSavedToTheLuaFile),
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _insert(String text) {
    final selection = _editor.selection;
    final start = selection.isValid ? selection.start : _editor.text.length;
    final end = selection.isValid ? selection.end : start;
    _editor.value = TextEditingValue(
      text: _editor.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _focus.requestFocus();
  }

  void _setPins(bool enabled) {
    var changed = 0;
    final text = _editor.text.replaceAllMapped(
      RegExp(
        r'^([ \t]*)(--[ \t]*)?(setManifestid[ \t]*\([^\r\n]*\))[ \t]*$',
        multiLine: true,
      ),
      (match) {
        if ((match[2] == null) == enabled) return match[0]!;
        changed++;
        return '${match[1]}${enabled ? '' : '-- '}${match[3]}';
      },
    );
    _editor.text = text;
    ui.showAppFeedback(
      context,
      context.l10n.manifestPinsSaveToApply(
        (changed).toString(),
        ((enabled ? context.l10n.enabled2 : context.l10n.commented)).toString(),
      ),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: (!_dirty && !_saving) || _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: ui.CommonScaffold(
        title:
            '${context.l10n.editLua} · ${widget.game.name}${_dirty ? ' *' : ''}',
        backAction: _close,
        actions: [
          ui.CommonPopupBox(
            key: const ValueKey('lua-editor-tools'),
            targetBuilder: (open) => IconButton(
              tooltip: context.l10n.more,
              onPressed: _loading || _saving ? null : open,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(40),
                fixedSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const CircleBorder(),
              ),
              icon: const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
            ),
            popupBuilder: (_) => ui.CommonPopupMenu(
              items: [
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.code,
                  label: 'addappid(AppID)',
                  onPressed: _loading || _saving
                      ? null
                      : () => _insert('addappid(${widget.game.appId})\n'),
                ),
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.code,
                  label: 'addappid(DepotID, 1, "key")',
                  onPressed: _loading || _saving
                      ? null
                      : () => _insert('addappid(DepotID, 1, "key")\n'),
                ),
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.code,
                  label: 'addtoken(AppID, "token")',
                  onPressed: _loading || _saving
                      ? null
                      : () => _insert(
                          'addtoken(${widget.game.appId}, "token")\n',
                        ),
                ),
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.code,
                  label: 'setManifestid',
                  onPressed: _loading || _saving
                      ? null
                      : () => _insert(
                          'setManifestid(DepotID, "manifestId", 0)\n',
                        ),
                ),
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.pin,
                  label: context.l10n.enablePins,
                  section: const ui.CommonPopupMenuSection(),
                  onPressed: _loading || _saving ? null : () => _setPins(true),
                ),
                ui.CommonPopupMenuItem(
                  glyph: ui.AppGlyphs.lockOpen,
                  label: context.l10n.disablePins,
                  onPressed: _loading || _saving ? null : () => _setPins(false),
                ),
              ],
            ),
          ),
        ],
        trailingAction: IconButton(
          key: const ValueKey('lua-editor-save'),
          tooltip: context.l10n.save,
          onPressed: _loading || _saving || !_dirty || !_loaded ? null : _save,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(40),
            fixedSize: const Size.square(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
          ),
          icon: const ui.GlyphIcon(ui.AppGlyphs.check, size: 20),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            ui.pageContentTopInset,
            24,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                'AppID ${widget.game.appId} · ${widget.game.luaPath}',
              ),
              const SizedBox(height: 16),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ui.CommonProgressBar(value: null, height: 2),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ui.CommonCard(
                    isError: true,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(child: SelectableText(_error!)),
                        TextButton(
                          onPressed: _load,
                          child: Text(context.l10n.reload),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: ui.CommonCircleLoading.page())
                    : ui.FilledInputTheme(
                        borderRadius: ui.AppRadius.lg,
                        child: TextField(
                          key: const Key('lua-editor-content'),
                          controller: _editor,
                          focusNode: _focus,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          readOnly: _saving,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 13,
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            hintText: '-- Lua',
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.ctrlSToSaveOriginalBackedUpBeforeSavingLines(
                  (_editor.text.split('\n').length).toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
