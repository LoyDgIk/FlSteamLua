import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'lan_transfer_models.dart';
import 'lan_transfer_service.dart';
import 'lan_transfer_widgets.dart';

Future<TransferSession?> showLanTransferSendSheet(
  BuildContext context, {
  required LanTransferService service,
  required SettingsStore settings,
  required GameEntry game,
  String? initialPeerId,
}) => ui.showModalSideSheet<TransferSession>(
  context: context,
  builder: (_) => _SendGameSheet(
    service: service,
    settings: settings,
    game: game,
    initialPeerId: initialPeerId,
  ),
);

Future<TransferSession?> showLanTransferReceiveSheet(
  BuildContext context, {
  required LanTransferService service,
  required LanTransferOffer offer,
}) => ui.showModalSideSheet<TransferSession>(
  context: context,
  builder: (_) => _ReceiveOfferSheet(service: service, offer: offer),
);

Future<void> openLanTransferSessionPage(
  BuildContext context, {
  required LanTransferService service,
  required SettingsStore settings,
  required TransferSession session,
}) => Navigator.of(context).push(
  ui.buildAppPageRoute<void>(
    builder: (_) => LanTransferSessionPage(
      service: service,
      settings: settings,
      session: session,
    ),
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  ),
);

class LanTransferSessionPage extends StatelessWidget {
  const LanTransferSessionPage({
    super.key,
    required this.service,
    required this.settings,
    required this.session,
  });

  final LanTransferService service;
  final SettingsStore settings;
  final TransferSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final live =
          service.sessions
              .where((value) => value.id == session.id)
              .firstOrNull ??
          session;
      final running =
          live.status == TransferSessionStatus.preparing ||
          live.status == TransferSessionStatus.transferring ||
          live.status == TransferSessionStatus.paused ||
          live.status == TransferSessionStatus.waitingForApproval ||
          live.status == TransferSessionStatus.verifying ||
          live.status == TransferSessionStatus.waitingForSteamExit;
      final retryable =
          live.status == TransferSessionStatus.paused ||
          live.status == TransferSessionStatus.failed;
      return ui.CommonScaffold(
        title: live.gameName,
        actions: [
          if (live.direction == TransferDirection.send)
            ui.DashboardIconButton(
              glyph: live.status == TransferSessionStatus.failed
                  ? ui.AppGlyphs.refresh
                  : ui.AppGlyphs.playPause(0),
              tooltip: live.status == TransferSessionStatus.failed
                  ? context.l10n.lanRetryTransfer
                  : live.status == TransferSessionStatus.paused
                  ? context.l10n.lanResume
                  : context.l10n.lanPause,
              onPressed:
                  live.status == TransferSessionStatus.transferring || retryable
                  ? () async {
                      try {
                        if (retryable) {
                          await service.resume(live.id);
                        } else {
                          await service.pause(live.id);
                        }
                      } catch (error) {
                        if (context.mounted) ui.showAppError(context, error);
                      }
                    }
                  : null,
            ),
          ui.DashboardIconButton(
            glyph: ui.AppGlyphs.close,
            tooltip: context.l10n.lanCancelTransfer,
            onPressed: running ? () => service.cancel(live.id) : null,
          ),
        ],
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            ui.pageContentTopInset,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            TransferHero(
              session: live,
              settings: settings,
              onPause: live.direction == TransferDirection.send
                  ? () => service.pause(live.id)
                  : null,
              onResume: live.direction == TransferDirection.send
                  ? () => service.resume(live.id)
                  : null,
              onCancel: () => service.cancel(live.id),
            ),
            const SizedBox(height: 18),
            ui.generateSection(
              title: context.l10n.lanTransfer,
              items: [
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.devices, size: 20),
                  title: Text(
                    live.direction == TransferDirection.send
                        ? context.l10n.lanSendToLan
                        : context.l10n.lanReceiveTransfer,
                  ),
                  subtitle: Text(
                    context.l10n.lanTransferFromDevice(live.peer.alias),
                  ),
                ),
                if (live.targetLibraryRoot case final target?)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(
                      ui.AppGlyphs.resources,
                      size: 20,
                    ),
                    title: Text(context.l10n.lanDestinationLibrary),
                    subtitle: SelectableText(target),
                  ),
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.speed, size: 20),
                  title: Text(context.l10n.lanNetworkSpeed),
                  subtitle: Text(
                    '${formatTransferSpeed(live.speed)} · ${context.l10n.lanPeakSpeed} ${formatTransferSpeed(live.peakSpeed)}',
                  ),
                ),
                if (live.totalChunks > 0)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.layers, size: 20),
                    title: Text(context.l10n.lanChunkProgress),
                    subtitle: Text(
                      '${live.completedChunks}/${live.totalChunks} · ${context.l10n.lanCachedChunks} ${live.cachedChunks}',
                    ),
                  ),
              ],
              footer: context.l10n.lanSteamRestartNotice,
            ),
          ],
        ),
      );
    },
  );
}

class LanTransferPage extends StatefulWidget {
  const LanTransferPage({
    super.key,
    required this.service,
    required this.settings,
    required this.games,
  });

  final LanTransferService service;
  final SettingsStore settings;
  final List<GameEntry> games;

  @override
  State<LanTransferPage> createState() => _LanTransferPageState();
}

class _LanTransferPageState extends State<LanTransferPage> {
  bool _changingReceive = false;
  late final PageController _sectionController = PageController();
  int _section = 0;

  LanTransferService get service => widget.service;

  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    unawaited(
      service.ensureStarted().catchError((Object error) {
        if (mounted) ui.showAppError(context, error);
      }),
    );
  }

  @override
  void didUpdateWidget(LanTransferPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != service) {
      oldWidget.service.removeListener(_changed);
      service.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _sectionController.dispose();
    service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setReceive(bool enabled) async {
    setState(() => _changingReceive = true);
    try {
      await service.setReceiveEnabled(enabled);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _changingReceive = false);
    }
  }

  Future<void> _addDevice() async {
    final peer = await ui.showFormSheet<LanPeer>(
      context: context,
      builder: (_) => _AddDeviceSheet(service: service),
    );
    if (peer != null && mounted) {
      ui.showAppSuccess(
        context,
        '${context.l10n.lanConnectDevice} · ${peer.alias}',
      );
    }
  }

  Future<void> _chooseGame(LanPeer peer) async {
    final game = await ui.showModalSideSheet<GameEntry>(
      context: context,
      builder: (_) => _GamePickerSheet(games: widget.games),
    );
    if (game == null || !mounted) return;
    final session = await showLanTransferSendSheet(
      context,
      service: service,
      settings: widget.settings,
      game: game,
      initialPeerId: peer.fingerprint,
    );
    if (session != null && mounted) {
      await openLanTransferSessionPage(
        context,
        service: service,
        settings: widget.settings,
        session: session,
      );
    }
  }

  Future<void> _openOffer(LanTransferOffer offer) async {
    final session = await showLanTransferReceiveSheet(
      context,
      service: service,
      offer: offer,
    );
    if (session != null && mounted) {
      await openLanTransferSessionPage(
        context,
        service: service,
        settings: widget.settings,
        session: session,
      );
    }
  }

  Future<void> _forgetPeer(LanPeer peer) async {
    await service.forgetPeer(peer.fingerprint);
    if (mounted) {
      ui.showAppSuccess(
        context,
        '${context.l10n.lanForgetDevice} · ${peer.alias}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = service.activeSessions;
    final pending = service.offers;
    final recent = service.sessions
        .where(
          (session) =>
              session.status == TransferSessionStatus.completed ||
              session.status == TransferSessionStatus.failed ||
              session.status == TransferSessionStatus.cancelled,
        )
        .take(8)
        .toList();
    return ui.CommonScaffold(
      title: context.l10n.lanTransfer,
      actions: [
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.refresh,
          tooltip: context.l10n.lanRefreshDevices,
          onPressed: () {
            unawaited(service.ensureStarted());
          },
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.add,
          tooltip: context.l10n.lanAddDevice,
          onPressed: _addDevice,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.lanTransferSettings,
            items: [
              ui.DecorationListItem(
                key: const ValueKey('lan-receive-switch'),
                leading: ui.GlyphIcon(
                  service.receiveEnabled
                      ? ui.AppGlyphs.wifi
                      : ui.AppGlyphs.wifiOff,
                  size: 20,
                ),
                title: Text(context.l10n.allowLanTransfers),
                subtitle: Text(
                  service.receiveEnabled
                      ? context.l10n.lanReceiveEnabled
                      : context.l10n.allowLanTransfersDescription,
                ),
                onPressed: _changingReceive
                    ? null
                    : () => _setReceive(!service.receiveEnabled),
                trailing: ui.CommonSwitch(
                  value: service.receiveEnabled,
                  semanticLabel: context.l10n.allowLanTransfers,
                  onChanged: _changingReceive ? null : _setReceive,
                ),
              ),
              if (service.networkError case final error?)
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.warning, size: 20),
                  title: Text(context.l10n.lanNearbyDevices),
                  subtitle: SelectableText(error),
                ),
              _ChunkCacheRow(service: service),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 18),
            ui.generateSection(
              title: context.l10n.lanActiveTransfer,
              items: [
                for (final session in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => openLanTransferSessionPage(
                        context,
                        service: service,
                        settings: widget.settings,
                        session: session,
                      ),
                      child: TransferHero(
                        session: session,
                        settings: widget.settings,
                        onPause: session.direction == TransferDirection.send
                            ? () => service.pause(session.id)
                            : null,
                        onResume: session.direction == TransferDirection.send
                            ? () => service.resume(session.id)
                            : null,
                        onCancel: () => service.cancel(session.id),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 18),
            ui.generateSection(
              title: context.l10n.lanReceiveTransfer,
              items: [
                for (final offer in pending)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(
                      ui.AppGlyphs.cloudDownload,
                      size: 20,
                    ),
                    title: Text(offer.gameName),
                    subtitle: Text(
                      '${context.l10n.lanTransferFromDevice(offer.peer.alias)} · ${formatTransferBytes(offer.selectedBytes)}',
                    ),
                    onPressed: () => _openOffer(offer),
                    trailing: ui.TonalButton(
                      size: ui.TonalButtonSize.compact,
                      label: context.l10n.lanAccept,
                      glyph: ui.AppGlyphs.check,
                      onPressed: () => _openOffer(offer),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ui.SegmentedControl<int>(
            segments: [
              (0, context.l10n.lanNearbyDevices),
              (1, context.l10n.lanRecentTransfers),
            ],
            value: _section,
            onChanged: (value) {
              setState(() => _section = value);
              _sectionController.animateToPage(
                value,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: PageView(
              controller: _sectionController,
              onPageChanged: (value) => setState(() => _section = value),
              children: [_buildNearbyPage(), _buildHistoryPage(recent)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPage() => service.peers.isEmpty
      ? ui.NullStatus(
          label: context.l10n.lanNoDevices,
          description: context.l10n.lanNoDevicesDescription,
          illustration: ui.NullStatusIllustration.data,
          action: ui.TonalButton(
            label: context.l10n.lanAddDevice,
            glyph: ui.AppGlyphs.add,
            onPressed: _addDevice,
          ),
        )
      : ListView(
          padding: EdgeInsets.zero,
          children: [
            ui.generateSection(
              items: [
                for (final peer in service.peers)
                  ui.DecorationListItem(
                    leading: ui.GlyphIcon(
                      peer.trusted
                          ? ui.AppGlyphs.verified
                          : ui.AppGlyphs.devices,
                      size: 20,
                    ),
                    title: Text(peer.alias),
                    subtitle: Text(
                      '${peer.address}:${peer.port} · ${peer.trusted ? context.l10n.lanTrusted : context.l10n.lanUntrusted}',
                    ),
                    onPressed: () => _chooseGame(peer),
                    trailing: ui.CommonPopupBox(
                      targetBuilder: (open) => IconButton(
                        tooltip: context.l10n.manage2(peer.alias),
                        onPressed: open,
                        icon: const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
                      ),
                      popupBuilder: (_) => ui.CommonPopupMenu(
                        items: [
                          ui.CommonPopupMenuItem(
                            label: context.l10n.lanSendGame,
                            glyph: ui.AppGlyphs.send,
                            onPressed: () => _chooseGame(peer),
                          ),
                          if (peer.trusted)
                            ui.CommonPopupMenuItem(
                              label: context.l10n.lanForgetDevice,
                              glyph: ui.AppGlyphs.delete,
                              danger: true,
                              onPressed: () => _forgetPeer(peer),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
              footer: context.l10n.lanNearbyDevicesDescription,
            ),
          ],
        );

  Widget _buildHistoryPage(List<TransferSession> recent) => ListView(
    padding: EdgeInsets.zero,
    children: [
      ui.generateSection(
        items: [
          if (recent.isEmpty)
            ui.DecorationListItem(
              leading: const ui.GlyphIcon(ui.AppGlyphs.clock, size: 20),
              title: Text(context.l10n.lanHistoryEmpty),
            ),
          for (final session in recent)
            ui.DecorationListItem(
              leading: ui.GlyphIcon(
                session.direction == TransferDirection.send
                    ? ui.AppGlyphs.upload
                    : ui.AppGlyphs.cloudDownload,
                size: 20,
              ),
              title: Text(session.gameName),
              subtitle: Text(
                '${session.peer.alias} · ${formatTransferBytes(session.transferredBytes)}',
              ),
              trailing: ui.MetaChip(
                label: switch (session.status) {
                  TransferSessionStatus.completed => context.l10n.lanCompleted,
                  TransferSessionStatus.cancelled => context.l10n.lanCancelled,
                  _ => context.l10n.lanFailed,
                },
              ),
              onPressed: () => openLanTransferSessionPage(
                context,
                service: service,
                settings: widget.settings,
                session: session,
              ),
            ),
        ],
        footer: context.l10n.lanSteamRestartNotice,
      ),
    ],
  );
}

class _GamePickerSheet extends StatefulWidget {
  const _GamePickerSheet({required this.games});

  final List<GameEntry> games;

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  late final ui.AppBarSearchState _search = ui.AppBarSearchState(
    onSearch: (value) => setState(() => _query = value),
  );
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final games = widget.games
        .where(
          (game) =>
              game.isInstalled &&
              game.installPath != null &&
              game.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return ui.SideSheetScaffold(
      title: context.l10n.lanSendGame,
      searchState: _search,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ui.NullStatusSwitcher(
          isEmpty: games.isEmpty,
          nullStatus: ui.NullStatus(
            label: _query.isEmpty
                ? context.l10n.noInstalledGamesToTransfer
                : context.l10n.noSearchResults,
            description: _query.isEmpty
                ? context.l10n.installGameBeforeTransfer
                : null,
            illustration: ui.NullStatusIllustration.steam,
          ),
          child: ListView.separated(
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final game = games[index];
              return ui.CommonCard(
                padding: const EdgeInsets.all(14),
                onPressed: () => Navigator.pop(context, game),
                child: Row(
                  children: [
                    const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.listTitleStyle,
                          ),
                          Text(
                            'AppID ${game.appId} · ${formatTransferBytes(game.sizeOnDisk)}',
                            style: ui.AppTextStyle.caption1.of(context),
                          ),
                        ],
                      ),
                    ),
                    const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SendGameSheet extends StatefulWidget {
  const _SendGameSheet({
    required this.service,
    required this.settings,
    required this.game,
    this.initialPeerId,
  });

  final LanTransferService service;
  final SettingsStore settings;
  final GameEntry game;
  final String? initialPeerId;

  @override
  State<_SendGameSheet> createState() => _SendGameSheetState();
}

class _SendGameSheetState extends State<_SendGameSheet> {
  LanTransferPlanSummary? _plan;
  Object? _error;
  String? _peerId;
  final Set<String> _extraIds = {};
  bool _sending = false;
  bool _sent = false;

  LanTransferService get service => widget.service;

  @override
  void initState() {
    super.initState();
    _peerId = widget.initialPeerId;
    service.tasks.addListener(_taskChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  void _taskChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.tasks.removeListener(_taskChanged);
    final plan = _plan;
    if (plan != null && !_sent && !_sending) {
      unawaited(service.discardPlan(plan.planId));
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final plan = await service.tasks.run(
        context.l10n.lanPreparing,
        (task) => service.prepare(widget.game, task: task),
        appId: widget.game.appId,
      );
      if (!mounted) {
        await service.discardPlan(plan.planId);
        return;
      }
      setState(() {
        _plan = plan;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _send() async {
    final plan = _plan;
    final peer = service.peers
        .where((value) => value.fingerprint == _peerId)
        .firstOrNull;
    if (plan == null || peer == null || _sending) return;
    final noSelectedFiles = context.l10n.lanNoSelectedFiles;
    setState(() => _sending = true);
    try {
      if (plan.officialFiles == 0 &&
          plan.manifestFiles == 0 &&
          _extraIds.isEmpty) {
        throw StateError(noSelectedFiles);
      }
      final session = await service.send(peer, plan, _extraIds);
      _sent = true;
      if (mounted) Navigator.pop(context, session);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      } else if (!_sent) {
        await service.discardPlan(plan.planId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final peers = service.peers;
    final task = service.tasks.tasks.firstOrNull;
    final selectedPeer = peers
        .where((peer) => peer.fingerprint == _peerId)
        .firstOrNull;
    final extraEntries =
        plan?.optionalFiles ?? const <LanTransferOptionalFile>[];
    return ui.SideSheetScaffold(
      title: context.l10n.lanSendGame,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: _error != null
            ? ui.NullStatus(
                label: context.l10n.lanFailed,
                description: '$_error',
                illustration: ui.NullStatusIllustration.error,
              )
            : plan == null
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ui.CommonCircleLoading.page(),
                      const SizedBox(height: 18),
                      Text(
                        task?.message.isNotEmpty == true
                            ? task!.message
                            : context.l10n.lanPreparing,
                        textAlign: TextAlign.center,
                        style: ui.AppTextStyle.subheadline.of(context),
                      ),
                      const SizedBox(height: 12),
                      ui.CommonProgressBar(value: task?.progress, height: 5),
                    ],
                  ),
                ),
              )
            : ListView(
                children: [
                  ui.generateSection(
                    title: context.l10n.lanNearbyDevices,
                    items: [
                      ui.FormRowSelect<String>(
                        title: context.l10n.lanChooseDevice,
                        value: selectedPeer?.fingerprint,
                        options: [
                          for (final peer in peers)
                            (peer.fingerprint, peer.alias),
                        ],
                        onChanged: peers.isEmpty
                            ? null
                            : (value) => setState(() => _peerId = value),
                      ),
                      if (peers.isEmpty)
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.wifiOff,
                            size: 20,
                          ),
                          title: Text(context.l10n.lanNoDevices),
                          subtitle: Text(context.l10n.lanNoDevicesDescription),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ui.generateSection(
                    title: context.l10n.lanContentToTransfer,
                    items: [
                      _ComponentRow(
                        glyph: ui.AppGlyphs.verified,
                        title: context.l10n.lanOfficialFiles,
                        count: plan.officialFiles,
                        bytes: plan.officialBytes,
                        required: true,
                      ),
                      _ComponentRow(
                        glyph: ui.AppGlyphs.code,
                        title: context.l10n.lanLuaAndManifests,
                        count: plan.manifestFiles + (plan.luaAvailable ? 1 : 0),
                        bytes: plan.manifestBytes,
                        required: true,
                        extraText: plan.luaAvailable
                            ? '${widget.game.appId}.lua${plan.luaEnabled ? '' : ' · ${context.l10n.luaDisabled}'}'
                            : null,
                      ),
                    ],
                    footer: extraEntries.isEmpty
                        ? context.l10n.lanSteamRestartNotice
                        : null,
                  ),
                  if (extraEntries.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ui.generateSection(
                      title: context.l10n.lanExtraFiles,
                      items: [
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.importFile,
                            size: 20,
                          ),
                          title: Text(context.l10n.lanExtraFiles),
                          subtitle: Text(
                            context.l10n.fileCount('${_extraIds.length}'),
                          ),
                          trailing: const ui.GlyphIcon(
                            ui.AppGlyphs.chevronForward,
                            size: 18,
                          ),
                          onPressed: () => _chooseExtras(extraEntries),
                        ),
                      ],
                      footer: context.l10n.lanExtrasWarning,
                    ),
                  ],
                  if (!plan.manifestAvailable || plan.warnings.isNotEmpty)
                    const SizedBox(height: 18),
                  if (!plan.manifestAvailable || plan.warnings.isNotEmpty)
                    ui.CommonCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ui.GlyphIcon(ui.AppGlyphs.warning, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              plan.warnings.isEmpty
                                  ? context.l10n.lanNoManifestWarning
                                  : plan.warnings.join('\n'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  ui.TonalButton(
                    size: ui.TonalButtonSize.section,
                    glyph: ui.AppGlyphs.send,
                    label: _sending
                        ? context.l10n.lanPreparing
                        : context.l10n.lanSendGame,
                    onPressed: selectedPeer == null || _sending ? null : _send,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _chooseExtras(List<LanTransferOptionalFile> entries) async {
    final selected = await ui.showModalSideSheet<Set<String>>(
      context: context,
      builder: (_) =>
          _OptionalFilesSheet(entries: entries, selectedIds: _extraIds),
    );
    if (selected == null || !mounted) return;
    setState(
      () => _extraIds
        ..clear()
        ..addAll(selected),
    );
  }
}

class _OptionalFilesSheet extends StatefulWidget {
  const _OptionalFilesSheet({required this.entries, required this.selectedIds});

  final List<LanTransferOptionalFile> entries;
  final Set<String> selectedIds;

  @override
  State<_OptionalFilesSheet> createState() => _OptionalFilesSheetState();
}

class _OptionalFilesSheetState extends State<_OptionalFilesSheet> {
  late final Set<String> _selected = Set.of(widget.selectedIds);
  late final ui.AppBarSearchState _search = ui.AppBarSearchState(
    onSearch: (value) => setState(() => _query = value.toLowerCase()),
  );
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _query.isEmpty
        ? widget.entries
        : widget.entries
              .where(
                (entry) => entry.relativePath.toLowerCase().contains(_query),
              )
              .toList();
    return ui.SideSheetScaffold(
      title: context.l10n.lanExtraFiles,
      searchState: _search,
      actions: [
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.check,
          tooltip: context.l10n.confirm,
          onPressed: () => Navigator.pop(context, _selected),
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
          isEmpty: entries.isEmpty,
          nullStatus: ui.NullStatus(
            label: _query.isEmpty
                ? context.l10n.noAdditionalFiles
                : context.l10n.noSearchResults,
            illustration: ui.NullStatusIllustration.data,
          ),
          child: ui.CommonScrollBar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ui.ItemPositionProvider(
                  position: ui.ItemPosition.get(index, entries.length),
                  child: _OptionalFileRow(
                    entry: entry,
                    selected: _selected.contains(entry.id),
                    onChanged: (enabled) => setState(() {
                      if (enabled) {
                        _selected.add(entry.id);
                      } else {
                        _selected.remove(entry.id);
                      }
                    }),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiveOfferSheet extends StatefulWidget {
  const _ReceiveOfferSheet({required this.service, required this.offer});

  final LanTransferService service;
  final LanTransferOffer offer;

  @override
  State<_ReceiveOfferSheet> createState() => _ReceiveOfferSheetState();
}

class _ReceiveOfferSheetState extends State<_ReceiveOfferSheet> {
  late final Future<List<String>> _targets = widget.service.libraryTargets();
  String? _target;
  bool _remember = true;
  bool _accepting = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _targets,
    builder: (context, snapshot) {
      final targets = snapshot.data ?? const <String>[];
      _target ??= targets.firstOrNull;
      return ui.SideSheetScaffold(
        title: context.l10n.lanIncomingTransferTitle(widget.offer.gameName),
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            ui.SideSheetScaffold.headerHeight + 16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: snapshot.connectionState != ConnectionState.done
              ? const Center(child: ui.CommonCircleLoading.page())
              : ListView(
                  children: [
                    ui.generateSection(
                      title: context.l10n.lanTransfer,
                      items: [
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.devices,
                            size: 20,
                          ),
                          title: Text(widget.offer.peer.alias),
                          subtitle: Text(
                            context.l10n.lanTransferFromDevice(
                              widget.offer.peer.address,
                            ),
                          ),
                        ),
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.importFile,
                            size: 20,
                          ),
                          title: Text(context.l10n.lanGameFiles),
                          subtitle: Text(
                            '${formatTransferBytes(widget.offer.selectedBytes)} · ${widget.offer.fileCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ui.generateSection(
                      title: context.l10n.lanDestinationLibrary,
                      items: [
                        ui.FormRow(
                          title: context.l10n.lanDestinationLibrary,
                          trailing: ui.FormRowSelect<String>(
                            title: '',
                            value: _target,
                            options: [
                              for (final target in targets) (target, target),
                            ],
                            onChanged: targets.isEmpty
                                ? null
                                : (value) => setState(() => _target = value),
                          ),
                        ),
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.lock,
                            size: 20,
                          ),
                          title: Text(context.l10n.lanRememberDevice),
                          subtitle: Text(
                            context.l10n.lanAutomaticReceiveHint(
                              _target ?? context.l10n.notSelected,
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _remember = !_remember),
                          trailing: ui.CommonSwitch(
                            value: _remember,
                            onChanged: (value) =>
                                setState(() => _remember = value),
                          ),
                        ),
                        if (targets.isEmpty)
                          ui.DecorationListItem(
                            leading: const ui.GlyphIcon(
                              ui.AppGlyphs.warning,
                              size: 20,
                            ),
                            title: Text(context.l10n.lanNoLibrary),
                          ),
                      ],
                      footer: context.l10n.lanSelectDestinationDescription,
                    ),
                    if (widget.offer.warnings.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ui.CommonCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.offer.warnings.join('\n')),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _accepting
                                ? null
                                : () async {
                                    await widget.service.rejectOffer(
                                      widget.offer,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  },
                            child: Text(context.l10n.lanReject),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ui.TonalButton(
                          glyph: ui.AppGlyphs.check,
                          label: _remember
                              ? context.l10n.lanAcceptAndRemember
                              : context.l10n.lanAccept,
                          onPressed: _accepting || _target == null
                              ? null
                              : _accept,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.lanSteamRestartNotice,
                      style: ui.AppTextStyle.caption1.of(context),
                    ),
                  ],
                ),
        ),
      );
    },
  );

  Future<void> _accept() async {
    final target = _target;
    if (target == null) return;
    setState(() => _accepting = true);
    try {
      await widget.service.acceptOffer(
        widget.offer,
        targetLibraryRoot: target,
        remember: _remember,
      );
      final live = widget.service.sessions
          .where((session) => session.id == widget.offer.sessionId)
          .firstOrNull;
      final session =
          live ??
          TransferSession(
            id: widget.offer.sessionId,
            bundleId: widget.offer.bundleId,
            appId: widget.offer.appId,
            gameName: widget.offer.gameName,
            coverUrl: widget.offer.coverUrl,
            direction: TransferDirection.receive,
            peer: widget.offer.peer,
            status: TransferSessionStatus.preparing,
            totalBytes: widget.offer.selectedBytes,
            createdAt: DateTime.now(),
            targetLibraryRoot: target,
            totalChunks: widget.offer.chunkCount,
          );
      if (mounted) Navigator.pop(context, session);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.glyph,
    required this.title,
    required this.count,
    required this.bytes,
    required this.required,
    this.extraText,
  });

  final ui.Glyph glyph;
  final String title;
  final int count;
  final int bytes;
  final bool required;
  final String? extraText;

  @override
  Widget build(BuildContext context) {
    return ui.FormRow(
      title: title,
      leading: ui.GlyphIcon(glyph, size: 20),
      trailing: Text(
        '$count · ${formatTransferBytes(bytes)}'
        '${extraText == null ? '' : ' · $extraText'}',
      ),
    );
  }
}

class _OptionalFileRow extends StatelessWidget {
  const _OptionalFileRow({
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  final LanTransferOptionalFile entry;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ui.ListItem.toggle(
    title: Text(entry.relativePath),
    subtitle: Text(formatTransferBytes(entry.size)),
    leading: const ui.GlyphIcon(ui.AppGlyphs.importFile, size: 20),
    value: selected,
    onChanged: onChanged,
  );
}

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({required this.service});

  final LanTransferService service;

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (!RegExp(r'^[A-Za-z0-9.-]+(?::\d{1,5})?$').hasMatch(value)) {
      setState(() => _error = context.l10n.lanManualAddressInvalid);
      return;
    }
    final uri = Uri.tryParse('https://$value');
    if (uri == null || uri.host.isEmpty) {
      setState(() => _error = context.l10n.lanManualAddressInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final peer = await widget.service.addManualPeer(
        uri.host,
        port: uri.hasPort ? uri.port : lanTransferPort,
      );
      if (mounted) Navigator.pop(context, peer);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.lanAddDevice,
    onSave: _save,
    saving: _saving,
    error: _error,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.lanDeviceAddress,
              style: ui.AppTextStyle.subheadline.of(context, emphasized: true),
            ),
            const SizedBox(height: 10),
            ui.SearchField(
              controller: _controller,
              autofocus: true,
              height: 48,
              glyph: ui.AppGlyphs.devices,
              hintText: context.l10n.lanDeviceAddressHint,
              onSubmitted: _save,
              trailing: IconButton(
                tooltip: context.l10n.lanConnectDevice,
                onPressed: _saving ? null : _save,
                icon: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 20),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChunkCacheRow extends StatefulWidget {
  const _ChunkCacheRow({required this.service});

  final LanTransferService service;

  @override
  State<_ChunkCacheRow> createState() => _ChunkCacheRowState();
}

class _ChunkCacheRowState extends State<_ChunkCacheRow> {
  late Future<({int bytes, int files})> _stats = widget.service
      .chunkCacheStats();

  @override
  Widget build(BuildContext context) => FutureBuilder<({int bytes, int files})>(
    future: _stats,
    builder: (context, snapshot) {
      final stats = snapshot.data;
      return ui.DecorationListItem(
        leading: const ui.GlyphIcon(ui.AppGlyphs.layers, size: 20),
        title: Text(context.l10n.lanChunkCache),
        subtitle: Text(
          stats == null
              ? '--'
              : '${formatTransferBytes(stats.bytes)} · ${stats.files}\n${context.l10n.lanChunkCacheDescription}',
        ),
        onPressed: stats == null
            ? null
            : () async {
                final confirmed =
                    await ui.AppDialogs.confirm(
                      context,
                      title: context.l10n.lanClearChunkCache,
                      message: context.l10n.lanClearChunkCacheConfirmation,
                      destructive: true,
                    ) ??
                    false;
                if (!confirmed || !context.mounted) return;
                try {
                  await widget.service.clearChunkCache();
                  if (context.mounted) {
                    ui.showAppSuccess(
                      context,
                      context.l10n.lanChunkCacheCleared,
                    );
                    setState(() {
                      _stats = widget.service.chunkCacheStats();
                    });
                  }
                } catch (error) {
                  if (context.mounted) ui.showAppError(context, error);
                }
              },
        trailing: const ui.GlyphIcon(ui.AppGlyphs.clearAll, size: 18),
      );
    },
  );
}
