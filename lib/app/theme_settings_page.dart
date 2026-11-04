import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/settings_store.dart';
import '../core/system_appearance.dart';
import '../core/system_fonts.dart';
import '../ui/context.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;

const _defaultColors = <int>[
  0xff007aff,
  0xffcb30e0,
  0xffff2d55,
  0xffff383c,
  0xffff8d28,
  0xffffcc00,
  0xff34c759,
  0xff8e8e93,
];

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key, required this.settings});
  final SettingsStore settings;
  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late double _scaleDraft;
  SettingsStore get settings => widget.settings;
  @override
  void initState() {
    super.initState();
    _scaleDraft = settings.textScale;
    settings.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    settings.removeListener(_changed);
    super.dispose();
  }

  void _set(String key, Object value) {
    unawaited(settings.set(key, value));
  }

  ui.ColorStyle get _colorStyle => switch (settings.colorStyle) {
    'tinted' => ui.ColorStyle.tinted,
    'soft' => ui.ColorStyle.soft,
    'monochrome' => ui.ColorStyle.monochrome,
    _ => ui.ColorStyle.vivid,
  };
  Brightness get _previewBrightness => switch (settings.theme) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => MediaQuery.platformBrightnessOf(context),
  };
  Color get _themeSeed => Color(
    settings.themeFollowSystem ? systemAccentColor() : settings.themeSeed,
  );
  ({ColorScheme colorScheme, Color seed}) _schemeFor(
    Brightness brightness, {
    bool? pureBlack,
    Color? seed,
  }) {
    final color = ui
        .seededColorScheme(
          seedColor: seed ?? _themeSeed,
          brightness: brightness,
          style: _colorStyle,
        )
        .toPureBlack(pureBlack ?? settings.pureBlack);
    return (colorScheme: color, seed: seed ?? _themeSeed);
  }

  List<int> get _themeColors =>
      settings.themeColors.isEmpty ? _defaultColors : settings.themeColors;
  Future<void> _resetColors() async {
    final accepted = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: context.l10n.reset,
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.reset),
          ),
        ],
        child: Text(context.l10n.resetTip),
      ),
    );
    if (accepted != true) return;
    await settings.set('themeColors', _defaultColors);
    await settings.set('themeSeed', defaultThemeColor);
    await settings.set('themeFollowSystem', true);
    await settings.set('themeColorStyle', 'vivid');
  }

  Future<void> _addColor() async {
    final color = await _showThemeSheet<int>(
      context,
      (context) => _CustomColorSheet(initialColor: _themeSeed),
    );
    if (color == null) return;
    final colors = [..._themeColors];
    if (!colors.contains(color)) colors.add(color);
    await settings.set('themeColors', colors);
    await settings.set('themeSeed', color);
    await settings.set('themeFollowSystem', false);
  }

  Future<void> _editColor(int color) async {
    final edited = await _showThemeSheet<int>(
      context,
      (context) => _CustomColorSheet(initialColor: Color(color)),
    );
    if (edited == null || edited == color) return;
    final colors = [..._themeColors];
    final index = colors.indexOf(color);
    if (index == -1) return;
    if (!colors.contains(edited)) {
      colors[index] = edited;
    } else {
      colors.removeAt(index);
    }
    await settings.set('themeColors', colors);
    if (settings.themeSeed == color && !settings.themeFollowSystem) {
      await settings.set('themeSeed', edited);
    }
  }

  Future<void> _deleteColor(int color) async {
    final accepted = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: context.l10n.delete,
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
        child: Text(context.l10n.deleteColorTip),
      ),
    );
    if (accepted != true) return;
    final colors = [..._themeColors]..remove(color);
    await settings.set('themeColors', colors);
    if (settings.themeSeed == color && !settings.themeFollowSystem) {
      await settings.set('themeFollowSystem', true);
    }
  }

  Future<void> _chooseFont() async {
    final font = await _showThemeSheet<String?>(
      context,
      (context) => _FontFamilySheet(settings: settings),
    );
    if (font == null) return;
    await settings.set('fontFamily', font);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _schemeFor(_previewBrightness);
    final mode = settings.theme;
    final floating = settings.sidebarFloating;
    final liquidGlass = settings.liquidGlass != 'none';
    return ui.CommonScaffold(
      title: context.l10n.theme,
      backgroundColor: ui.SurfaceLevel.page.colorOf(context.colorScheme),
      body: ListView(
        padding: EdgeInsets.only(
          top: ui.pageContentTopInset,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _ThemeLivePreview(
            key: const ValueKey('theme-preview'),
            colorScheme: preview.colorScheme,
            floatingBar: floating,
            liquidGlass: liquidGlass,
            tabAnimation: settings.tabAnimation == 'slide'
                ? ui.MiniTabAnimation.slide
                : ui.MiniTabAnimation.fade,
          ),
          const SizedBox(height: 16),
          _themeModeItem(mode, floating, liquidGlass),
          const SizedBox(height: 16),
          _pureBlackItem(floating, liquidGlass),
          const SizedBox(height: 16),
          _primaryColorItem(),
          const SizedBox(height: 16),
          _navigationBarItem(floating, liquidGlass),
          const SizedBox(height: 16),
          _tabAnimationItem(floating, liquidGlass),
          const SizedBox(height: 16),
          _liquidGlassItem(),
          const SizedBox(height: 16),
          _sidebarBlurItem(),
          const SizedBox(height: 16),
          _fontFamilyItem(),
          const SizedBox(height: 16),
          _textScaleItem(),
        ],
      ),
    );
  }

  Widget _themeModeItem(String value, bool floating, bool liquidGlass) {
    final light = _schemeFor(Brightness.light).colorScheme;
    final dark = _schemeFor(Brightness.dark).colorScheme;
    return ui.PreviewChoiceGroup<String>(
      info: ui.Info(label: context.l10n.themeMode, glyph: ui.AppGlyphs.sun),
      value: value,
      keyBuilder: (value) => ValueKey('theme-mode-$value'),
      choices: [
        ui.PreviewChoice(
          value: 'system',
          label: context.l10n.auto,
          pictogram: ui.MiniScreenThumb(
            screen: ui.MiniSplitScreen(
              light: _MiniScreen(
                colorScheme: light,
                floatingBar: floating,
                liquidGlass: liquidGlass,
              ),
              dark: _MiniScreen(
                colorScheme: dark,
                floatingBar: floating,
                liquidGlass: liquidGlass,
              ),
            ),
          ),
        ),
        ui.PreviewChoice(
          value: 'light',
          label: context.l10n.light,
          pictogram: ui.MiniScreenThumb(
            screen: _MiniScreen(
              colorScheme: light,
              floatingBar: floating,
              liquidGlass: liquidGlass,
            ),
          ),
        ),
        ui.PreviewChoice(
          value: 'dark',
          label: context.l10n.dark,
          pictogram: ui.MiniScreenThumb(
            screen: _MiniScreen(
              colorScheme: dark,
              floatingBar: floating,
              liquidGlass: liquidGlass,
            ),
          ),
        ),
      ],
      onChanged: (value) => _set('theme', value),
    );
  }

  Widget _pureBlackItem(bool floating, bool liquidGlass) {
    Widget preview(bool pureBlack) => ui.MiniScreenThumb(
      screen: _MiniScreen(
        colorScheme: _schemeFor(
          Brightness.dark,
          pureBlack: pureBlack,
        ).colorScheme,
        floatingBar: floating,
        liquidGlass: liquidGlass,
      ),
    );
    return ui.PreviewChoiceGroup<bool>(
      info: ui.Info(
        label: context.l10n.pureBlackMode,
        glyph: ui.AppGlyphs.pureBlack,
      ),
      value: settings.pureBlack,
      keyBuilder: (value) =>
          ValueKey(value ? 'theme-pure-black' : 'theme-pure-black-standard'),
      choices: [
        ui.PreviewChoice(
          value: false,
          label: context.l10n.standard,
          pictogram: preview(false),
        ),
        ui.PreviewChoice(
          value: true,
          label: context.l10n.pureBlack,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) => _set('themePureBlack', value),
    );
  }

  Widget _primaryColorItem() {
    final colors = _themeColors;
    final followSystem = settings.themeFollowSystem;
    final isDefault =
        followSystem &&
        _sameColors(colors, _defaultColors) &&
        _colorStyle == ui.ColorStyle.vivid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ui.InfoHeader(
          info: ui.Info(
            label: context.l10n.themeColor,
            glyph: ui.AppGlyphs.palette,
          ),
          actions: [
            if (!isDefault)
              IconButton(
                tooltip: context.l10n.reset,
                onPressed: _resetColors,
                icon: const ui.GlyphIcon(ui.AppGlyphs.reset, size: 20),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              _ColorSwatches(
                colors: colors,
                selected: followSystem ? null : settings.themeSeed,
                systemColor: Color(systemAccentColor()),
                onSelect: (color) {
                  if (color == null) {
                    unawaited(
                      Future.wait([
                        settings.set('themeFollowSystem', true),
                        settings.set('themeSeed', defaultThemeColor),
                      ]),
                    );
                  } else {
                    unawaited(
                      Future.wait([
                        settings.set('themeFollowSystem', false),
                        settings.set('themeSeed', color),
                      ]),
                    );
                  }
                },
                onEdit: _editColor,
                onDelete: _deleteColor,
                onAdd: _addColor,
              ),
              ui.generateGroup([
                ui.ListItem<ui.ColorStyle>.options(
                  key: const ValueKey('theme-color-style'),
                  title: Text(context.l10n.colorStyle),
                  options: ui.ColorStyle.values,
                  value: _colorStyle,
                  textBuilder: _colorStyleLabel,
                  onChanged: (style) => _set('themeColorStyle', style.name),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navigationBarItem(bool floating, bool liquidGlass) {
    final scheme = _schemeFor(_previewBrightness).colorScheme;
    Widget preview(bool floating) => ui.MiniScreenThumb(
      screen: _MiniScreen(
        colorScheme: scheme,
        floatingBar: floating,
        liquidGlass: floating && liquidGlass,
      ),
    );
    return ui.PreviewChoiceGroup<bool>(
      info: ui.Info(
        label: context.l10n.navigationBarStyle,
        glyph: ui.AppGlyphs.layers,
      ),
      value: floating,
      keyBuilder: (value) =>
          ValueKey(value ? 'navigation-floating' : 'navigation-docked'),
      choices: [
        ui.PreviewChoice(
          value: true,
          label: context.l10n.floating,
          pictogram: preview(true),
        ),
        ui.PreviewChoice(
          value: false,
          label: context.l10n.docked,
          pictogram: preview(false),
        ),
      ],
      onChanged: (value) => _set('sidebarFloating', value),
    );
  }

  Widget _tabAnimationItem(bool floating, bool liquidGlass) {
    final scheme = _schemeFor(_previewBrightness).colorScheme;
    Widget preview(ui.MiniTabAnimation animation) => ui.MiniScreenThumb(
      screen: _MiniScreen(
        colorScheme: scheme,
        floatingBar: floating,
        liquidGlass: liquidGlass,
        selected: 1,
        previous: 0,
        progress: .55,
        tabAnimation: animation,
      ),
    );
    return ui.PreviewChoiceGroup<String>(
      info: ui.Info(
        label: context.l10n.tabAnimation,
        glyph: ui.AppGlyphs.motion,
      ),
      value: settings.tabAnimation,
      keyBuilder: (value) => ValueKey('tab-animation-$value'),
      choices: [
        ui.PreviewChoice(
          value: 'slide',
          label: context.l10n.slide,
          pictogram: preview(ui.MiniTabAnimation.slide),
        ),
        ui.PreviewChoice(
          value: 'fade',
          label: context.l10n.fade,
          pictogram: preview(ui.MiniTabAnimation.fade),
        ),
      ],
      onChanged: (value) => _set('tabAnimation', value),
    );
  }

  Widget _liquidGlassItem() {
    final scheme = _schemeFor(_previewBrightness).colorScheme;
    Widget preview(bool glass) => ui.MiniScreenThumb(
      screen: _MiniScreen(
        colorScheme: scheme,
        floatingBar: true,
        liquidGlass: glass,
        selected: 1,
      ),
    );
    return ui.PreviewChoiceGroup<String>(
      info: ui.Info(
        label: context.l10n.liquidGlass,
        glyph: ui.AppGlyphs.liquidGlass,
      ),
      value: settings.liquidGlass,
      keyBuilder: (value) => ValueKey('liquid-glass-$value'),
      choices: [
        ui.PreviewChoice(
          value: 'none',
          label: context.l10n.none,
          pictogram: preview(false),
        ),
        ui.PreviewChoice(
          value: 'standard',
          label: context.l10n.standard,
          pictogram: preview(true),
        ),
        ui.PreviewChoice(
          value: 'ultra',
          label: context.l10n.ultra,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) => _set('liquidGlass', value),
    );
  }

  Widget _sidebarBlurItem() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ui.InfoHeader(
        info: ui.Info(label: context.l10n.sidebar, glyph: ui.AppGlyphs.blur),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ui.generateGroup([
              ui.ListItem.toggle(
                key: const ValueKey('sidebar-blur'),
                title: Text(context.l10n.backgroundBlur),
                value: settings.sidebarBlur,
                onChanged: (value) => _set('sidebarBlur', value),
              ),
            ]),
            ui.ListFooter(text: context.l10n.sidebarBlurDesc),
          ],
        ),
      ),
    ],
  );
  Widget _fontFamilyItem() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ui.InfoHeader(
        info: ui.Info(label: context.l10n.fontFamily, glyph: ui.AppGlyphs.font),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ui.CommonCard(
          key: const ValueKey('font-family'),
          onPressed: _chooseFont,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              spacing: 12,
              children: [
                Text(
                  'Aa',
                  style: ui.AppTextStyle.headline
                      .of(context)
                      .copyWith(fontFamily: settings.fontFamily),
                ),
                Expanded(
                  child: Text(
                    settings.fontFamily ?? context.l10n.defaultText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui.AppTextStyle.subheadline
                        .of(context)
                        .copyWith(
                          fontFamily: settings.fontFamily,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Widget _textScaleItem() {
    final scale = settings.textScaleEnabled ? _scaleDraft : 1.0;
    final percent = '${(scale * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ui.InfoHeader(
          info: ui.Info(
            label: context.l10n.textScale,
            glyph: ui.AppGlyphs.textSize,
          ),
          actions: [
            if (settings.textScaleEnabled && settings.textScale != 1)
              IconButton(
                tooltip: context.l10n.reset,
                onPressed: () {
                  setState(() => _scaleDraft = 1);
                  _set('textScale', 1.0);
                },
                icon: const ui.GlyphIcon(ui.AppGlyphs.reset, size: 20),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            spacing: 8,
            children: [
              ui.SegmentedControl<bool>(
                key: const ValueKey('text-scale-mode'),
                segments: [
                  (false, context.l10n.followSystem),
                  (true, context.l10n.custom),
                ],
                value: settings.textScaleEnabled,
                onChanged: (value) => _set('textScaleEnabled', value),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(
                    context.colorScheme,
                  ),
                  shape: ui.AppShape.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(
                          child: AnimatedSize(
                            duration: context.motionDuration(
                              const Duration(milliseconds: 200),
                            ),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(textScaler: TextScaler.linear(scale)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  Text(
                                    'Aa',
                                    style: ui.AppTextStyle.title3.of(context),
                                  ),
                                  Text(
                                    context.l10n.textScalePreview,
                                    style: ui.AppTextStyle.subheadline
                                        .of(context)
                                        .copyWith(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: ShapeDecoration(
                            color: context.raisedSurfaceLevel.next.colorOf(
                              context.colorScheme,
                            ),
                            shape: ui.AppShape.full,
                          ),
                          child: Text(
                            percent,
                            style: ui.AppTextStyle.subheadline
                                .of(context, emphasized: true)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MediaQuery.withNoTextScaling(
                      child: Row(
                        spacing: 12,
                        children: [
                          Text(
                            'A',
                            style: ui.AppTextStyle.footnote
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                          Expanded(
                            child: Slider(
                              key: const ValueKey('text-scale'),
                              min: .8,
                              max: 1.5,
                              divisions: 14,
                              value: scale.clamp(.8, 1.5),
                              label: percent,
                              onChanged: settings.textScaleEnabled
                                  ? (value) =>
                                        setState(() => _scaleDraft = value)
                                  : null,
                              onChangeEnd: (value) => _set('textScale', value),
                            ),
                          ),
                          Text(
                            'A',
                            style: ui.AppTextStyle.title2
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _colorStyleLabel(ui.ColorStyle style) => switch (style) {
    ui.ColorStyle.vivid => context.l10n.vivid,
    ui.ColorStyle.tinted => context.l10n.tinted,
    ui.ColorStyle.soft => context.l10n.soft,
    ui.ColorStyle.monochrome => context.l10n.monochrome,
  };
}

typedef _MiniScreen = ui.MiniScreen;
bool _sameColors(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

class _SchemeTween extends Tween<ColorScheme> {
  _SchemeTween({super.end});
  @override
  ColorScheme lerp(double t) => ColorScheme.lerp(begin!, end!, t);
}

class _ThemeLivePreview extends StatefulWidget {
  const _ThemeLivePreview({
    super.key,
    required this.colorScheme,
    required this.floatingBar,
    required this.liquidGlass,
    required this.tabAnimation,
  });
  final ColorScheme colorScheme;
  final bool floatingBar;
  final bool liquidGlass;
  final ui.MiniTabAnimation tabAnimation;
  @override
  State<_ThemeLivePreview> createState() => _ThemeLivePreviewState();
}

class _ThemeLivePreviewState extends State<_ThemeLivePreview>
    with SingleTickerProviderStateMixin {
  static const double _phoneWidth = 168;
  static const _duration = Duration(milliseconds: 300);
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: ui.containerTransitionDuration,
  );
  late final CurvedAnimation _slideCurve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOut,
  );
  int _selected = 0;
  int? _previous;
  @override
  void didUpdateWidget(_ThemeLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabAnimation != widget.tabAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_select((_selected + 1) % ui.MiniScreen.destinationCount));
        }
      });
    }
  }

  Future<void> _select(int index) async {
    if (index == _selected) return;
    final fade = widget.tabAnimation == ui.MiniTabAnimation.fade;
    _slide.duration = fade
        ? ui.fadeTabDuration
        : ui.containerTransitionDuration;
    _slideCurve.curve = fade ? ui.fadeTabCurve : Curves.easeOut;
    setState(() {
      _previous = _selected;
      _selected = index;
    });
    await _slide.forward(from: 0).orCancel.catchError((_) {});
    if (mounted && _selected == index) {
      setState(() => _previous = null);
    }
  }

  @override
  void dispose() {
    _slideCurve.dispose();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corner = ui.AppCorner.fit(_phoneWidth);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
        shape: ui.AppShape.xxl,
      ),
      child: SizedBox(
        width: _phoneWidth,
        child: AspectRatio(
          aspectRatio: 9 / 17,
          child: ClipRSuperellipse(
            borderRadius: ui.AppRadius.all(corner),
            child: TweenAnimationBuilder<ColorScheme>(
              tween: _SchemeTween(end: widget.colorScheme),
              duration: context.motionDuration(_duration),
              builder: (_, colorScheme, _) => AnimatedSwitcher(
                duration: context.motionDuration(_duration),
                child: AnimatedBuilder(
                  key: ValueKey((widget.floatingBar, widget.liquidGlass)),
                  animation: _slideCurve,
                  builder: (_, _) => ui.MiniScreen(
                    colorScheme: colorScheme,
                    floatingBar: widget.floatingBar,
                    liquidGlass: widget.liquidGlass,
                    selected: _selected,
                    previous: _previous,
                    progress: _previous == null ? 1 : _slideCurve.value,
                    tabAnimation: widget.tabAnimation,
                    onSelect: _select,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> _showThemeSheet<T>(BuildContext context, WidgetBuilder builder) {
  return ui.showModalSideSheet<T>(context: context, builder: builder);
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.colors,
    required this.selected,
    required this.systemColor,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });
  final List<int> colors;
  final int? selected;
  final Color systemColor;
  final ValueChanged<int?> onSelect;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final level = context.raisedSurfaceLevel;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: level.colorOf(context.colorScheme),
        shape: ui.AppShape.xl,
      ),
      child: ui.SurfaceScope(
        level: level,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const cell = 44.0;
            const gap = 6.0;
            final columns = math.max(
              1,
              ((constraints.maxWidth + gap) / (cell + gap)).floor(),
            );
            final spacing = columns > 1
                ? (constraints.maxWidth - columns * cell) / (columns - 1)
                : 0.0;
            return Wrap(
              spacing: spacing,
              runSpacing: gap,
              children: [
                _ColorSwatch(
                  color: null,
                  fill: systemColor,
                  selected: selected == null,
                  label: context.l10n.followSystem,
                  onPressed: () => onSelect(null),
                ),
                for (final color in colors)
                  _ColorSwatch(
                    color: color,
                    fill: Color(color),
                    selected: selected == color,
                    label: Color(color).hex,
                    onPressed: () => onSelect(color),
                    onEdit: () => onEdit(color),
                    onDelete: () => onDelete(color),
                  ),
                _AddColorButton(
                  key: const ValueKey('theme-color-add'),
                  onPressed: onAdd,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.fill,
    required this.selected,
    required this.label,
    required this.onPressed,
    this.onEdit,
    this.onDelete,
  });
  final int? color;
  final Color fill;
  final bool selected;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final check = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final swatch = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox.square(
        dimension: 44,
        child: Material(
          type: MaterialType.transparency,
          shape: ui.AppShape.circle,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: ui.AppShape.circle,
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: context.motionDuration(
                    const Duration(milliseconds: 200),
                  ),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: ui.AppShape.circle.copyWith(
                        side: BorderSide(color: fill, width: 2.5),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                SizedBox.square(
                  dimension: 32,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: ui.AppShape.circle,
                    ),
                  ),
                ),
                if (color == null)
                  const PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: _EyedropperBadge(),
                  ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: context.motionDuration(
                    const Duration(milliseconds: 200),
                  ),
                  curve: Curves.easeOutBack,
                  child: ui.GlyphIcon(
                    ui.AppGlyphs.check,
                    size: 18,
                    fill: 1,
                    color: check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (onEdit == null || onDelete == null) return swatch;
    return ui.ContextMenuRegion(
      menuItems: [
        ui.CommonPopupMenuItem(
          glyph: ui.AppGlyphs.edit,
          label: context.l10n.edit,
          onPressed: onEdit!,
        ),
        ui.CommonPopupMenuItem(
          glyph: ui.AppGlyphs.delete,
          label: context.l10n.delete,
          danger: true,
          onPressed: onDelete!,
        ),
      ],
      child: swatch,
    );
  }
}

class _EyedropperBadge extends StatelessWidget {
  const _EyedropperBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: ShapeDecoration(
      color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
      shape: ui.AppShape.circle,
    ),
    child: const Center(child: ui.GlyphIcon(ui.AppGlyphs.eyedropper, size: 12)),
  );
}

class _AddColorButton extends StatelessWidget {
  const _AddColorButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.add,
    child: Semantics(
      button: true,
      child: SizedBox.square(
        dimension: 44,
        child: Material(
          type: MaterialType.transparency,
          shape: ui.AppShape.circle,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: ui.AppShape.circle,
            onTap: onPressed,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(
                    context.colorScheme,
                  ),
                  shape: ui.AppShape.circle,
                ),
                child: ui.GlyphIcon(
                  ui.AppGlyphs.add,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({required this.initialColor});
  final Color initialColor;
  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late final ValueNotifier<Color> _controller = ValueNotifier(
    widget.initialColor,
  );
  void _confirm() {
    Navigator.pop(context, _controller.value.toARGB32());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.customColor,
    actions: [
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.confirm,
        onPressed: _confirm,
        icon: const ui.GlyphIcon(ui.AppGlyphs.check, size: 20),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        ui.SideSheetScaffold.headerHeight + 16,
        16,
        20,
      ),
      children: [
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (_, color, _) => _CustomColorPreview(
            color: color,
            onChanged: (value) => _controller.value = value,
          ),
        ),
        const SizedBox(height: 16),
        ui.Palette(controller: _controller),
      ],
    ),
  );
}

class _CustomColorPreview extends StatelessWidget {
  const _CustomColorPreview({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;
  @override
  Widget build(BuildContext context) {
    final level = context.raisedSurfaceLevel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: level.colorOf(context.colorScheme),
        shape: ui.AppShape.xl,
      ),
      child: ui.SurfaceScope(
        level: level,
        child: Row(
          spacing: 12,
          children: [
            for (final brightness in Brightness.values)
              ExcludeSemantics(
                child: SizedBox(
                  width: 72,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: ui.AppRadius.md,
                    child: FittedBox(
                      child: SizedBox(
                        width: 96,
                        height: 128,
                        child: ui.MiniScreen(
                          colorScheme: ui.seededColorScheme(
                            seedColor: color,
                            brightness: brightness,
                          ),
                          floatingBar: true,
                          liquidGlass: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ui.HexColorField(color: color, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontFamilySheet extends StatefulWidget {
  const _FontFamilySheet({required this.settings});
  final SettingsStore settings;
  @override
  State<_FontFamilySheet> createState() => _FontFamilySheetState();
}

class _FontFamilySheetState extends State<_FontFamilySheet> {
  List<String>? _fonts;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final fonts = await loadSystemFontFamilies();
    if (mounted) setState(() => _fonts = fonts);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fonts = _fonts;
    final query = _search.text.trim().toLowerCase();
    final filtered = fonts
        ?.where((font) => font.toLowerCase().contains(query))
        .toList();
    return ui.SideSheetScaffold(
      title: context.l10n.fontFamily,
      searchState: ui.AppBarSearchState(
        onSearch: (query) {
          _search.text = query;
          setState(() {});
        },
      ),
      body: fonts == null
          ? const Center(child: ui.CommonCircleLoading.page())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                ui.SideSheetScaffold.headerHeight + 16,
                16,
                20,
              ),
              children: [
                ui.generateGroup([
                  _FontRow(
                    family: '',
                    label: context.l10n.defaultText,
                    selected: widget.settings.fontFamily == null,
                  ),
                ]),
                const SizedBox(height: 24),
                ui.ListHeader(title: context.l10n.installedFonts),
                ui.generateGroup([
                  for (final font in filtered!)
                    _FontRow(
                      family: font,
                      label: font,
                      selected: widget.settings.fontFamily == font,
                    ),
                ]),
              ],
            ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.family,
    required this.label,
    required this.selected,
  });
  final String family;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => ui.ListItem<void>(
    title: Text(label, style: TextStyle(fontFamily: family)),
    onTap: () => Navigator.pop(context, family),
    trailing: selected ? const ui.SelectionCheck() : null,
  );
}
