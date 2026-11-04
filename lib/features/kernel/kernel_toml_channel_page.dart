import 'package:flutter/material.dart';

import '../../core/steam_process_actions.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'kernel_service.dart';
import 'kernel_toml_build_sheet.dart';

const _customRepository = '__custom__';

class KernelTomlChannelPage extends StatefulWidget {
  const KernelTomlChannelPage({
    super.key,
    required this.service,
    this.steamProcess,
  });

  final KernelService service;
  final SteamProcessActions? steamProcess;

  @override
  State<KernelTomlChannelPage> createState() => _KernelTomlChannelPageState();
}

class _KernelTomlChannelPageState extends State<KernelTomlChannelPage> {
  final _repository = TextEditingController();
  final _channel = TextEditingController();
  late String _repositoryChoice;
  String _customRepositoryValue = '';
  KernelTomlChannelMode _mode = KernelTomlChannelMode.branch;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.service.tomlChannelSettings;
    _repository.text = value.repository;
    _channel.text = value.channel;
    final preset = kernelTomlChannelRepositories.contains(value.repository);
    _repositoryChoice = preset ? value.repository : _customRepository;
    if (!preset) _customRepositoryValue = value.repository;
    _mode = value.mode;
  }

  @override
  void dispose() {
    _repository.dispose();
    _channel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repository = _repositoryChoice == _customRepository
        ? _repository.text.trim()
        : _repositoryChoice;
    final channel = _channel.text.trim();
    if (repository.isEmpty || channel.isEmpty) {
      ui.showAppError(context, context.l10n.kernelRepositoryHint);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.saveTomlChannelSettings(
        KernelTomlChannelSettings(
          repository: repository,
          channel: channel,
          mode: _mode,
        ),
      );
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.operationCompleted);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLocalBuild() => showLocalTomlBuildSheet(
    context: context,
    service: widget.service,
    steamProcess: widget.steamProcess,
  );

  void _selectRepository(String? value) {
    if (value == null) return;
    setState(() {
      if (_repositoryChoice == _customRepository) {
        _customRepositoryValue = _repository.text;
      }
      _repositoryChoice = value;
      _repository.text = value == _customRepository
          ? _customRepositoryValue
          : value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final custom = _repositoryChoice == _customRepository;
    return ui.CommonScaffold(
      title: context.l10n.steamClientDataChannel,
      isLoading: _saving,
      actions: [
        IconButton(
          tooltip: context.l10n.save,
          onPressed: _saving ? null : _save,
          icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.steamClientDataChannel,
            items: [
              ui.FormRowSelect<String>(
                title: context.l10n.channelRepository,
                value: _repositoryChoice,
                options: [
                  for (final repository in kernelTomlChannelRepositories)
                    (
                      repository,
                      repository == kernelDefaultTomlRepository
                          ? '$repository · ${context.l10n.defaultRepository}'
                          : repository,
                    ),
                  (_customRepository, context.l10n.customRepository),
                ],
                onChanged: _saving ? (_) {} : _selectRepository,
              ),
              AnimatedSize(
                duration: context.motionDuration(
                  const Duration(milliseconds: 220),
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: custom
                    ? ui.FadeBox(
                        child: ui.FormRow(
                          title: context.l10n.channelRepository,
                          trailing: ui.FormRowTextField(
                            controller: _repository,
                            keyboardType: TextInputType.url,
                            hintText: 'owner/repository',
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ui.FormRow(
                title: context.l10n.channelName,
                trailing: ui.FormRowTextField(
                  controller: _channel,
                  hintText: 'main',
                ),
              ),
              ui.FormRowSelect<KernelTomlChannelMode>(
                title: context.l10n.channelFormat,
                value: _mode,
                options: [
                  (
                    KernelTomlChannelMode.branch,
                    context.l10n.channelFormatBranch,
                  ),
                  (
                    KernelTomlChannelMode.directory,
                    context.l10n.channelFormatDirectory,
                  ),
                ],
                onChanged: _saving
                    ? (_) {}
                    : (value) {
                        if (value != null) setState(() => _mode = value);
                      },
              ),
            ],
          ),
          ui.generateSection(
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.wrench),
                title: Text(context.l10n.localTemporaryBuild),
                subtitle: Text(context.l10n.localTemporaryBuildDescription),
                onPressed: _saving ? null : _openLocalBuild,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
