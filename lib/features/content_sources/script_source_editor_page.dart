import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../manifests/manifest_script_parser.dart';
import '../manifests/manifest_source_service.dart';

class ScriptSourceEditorPage extends StatefulWidget {
  const ScriptSourceEditorPage({
    super.key,
    required this.service,
    required this.sourceId,
    required this.title,
  });

  final ManifestSourceService service;
  final String sourceId;
  final String title;

  @override
  State<ScriptSourceEditorPage> createState() => _ScriptSourceEditorPageState();
}

class _ScriptSourceEditorPageState extends State<ScriptSourceEditorPage> {
  final _editor = TextEditingController();
  final _focus = FocusNode();
  String _saved = '';
  String? _error;
  bool _loading = true;
  bool _saving = false;
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
      final text = widget.service.scriptFor(widget.sourceId);
      if (!mounted) return;
      _saved = text;
      _editor.text = text;
      setState(() {
        _loading = false;
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
    if (_loading || _saving || !_dirty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final text = _editor.text;
    try {
      await widget.service.saveScript(widget.sourceId, text);
      if (!mounted) return;
      setState(() => _saved = text);
      ui.showAppSuccess(context, context.l10n.scriptSaved);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _validate() {
    try {
      final definition = ManifestScriptParser.parse(_editor.text);
      if (definition.id != widget.sourceId) {
        throw FormatException(
          'Script ID changed from ${widget.sourceId} to ${definition.id}',
        );
      }
      ui.showAppSuccess(context, context.l10n.scriptIsValid);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await ui.showFlDialog<bool>(
        context: context,
        builder: (context) => ui.CommonDialog(
          title: context.l10n.discardUnsavedChanges,
          destructive: true,
          actions: [
            ui.CommonDialogAction(
              label: context.l10n.keepEditing,
              onPressed: () => Navigator.pop(context, false),
            ),
            ui.CommonDialogAction(
              label: context.l10n.discard,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          child: Text(context.l10n.theseScriptChangesHaveNotBeenSaved),
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
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
        isLoading: _saving,
        title:
            '${context.l10n.editScript} · ${widget.title}${_dirty ? ' *' : ''}',
        backAction: _close,
        actions: [
          ui.CommonPopupBox(
            key: const ValueKey('script-tools'),
            targetBuilder: (open) => IconButton(
              tooltip: context.l10n.more,
              onPressed: _loading ? null : open,
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
                  glyph: ui.AppGlyphs.verified,
                  label: context.l10n.validateScript,
                  onPressed: _loading ? null : _validate,
                ),
              ],
            ),
          ),
        ],
        trailingAction: IconButton(
          key: const ValueKey('script-save'),
          tooltip: context.l10n.save,
          onPressed: _loading || _saving || !_dirty ? null : _save,
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
            20,
            ui.pageContentTopInset,
            20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.sourceId}.js',
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                ui.CommonCard(
                  isError: true,
                  inert: true,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(_error!),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: _loading
                    ? const Center(child: ui.CommonCircleLoading.page())
                    : ui.FilledInputTheme(
                        borderRadius: ui.AppRadius.lg,
                        child: TextField(
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
                            hintText: '// JavaScript',
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_editor.text.split('\n').length} lines · Ctrl+S',
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
