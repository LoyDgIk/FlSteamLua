// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'item_position.dart';

class PageActivityScope extends InheritedWidget {
  final bool isActive;

  const PageActivityScope({
    super.key,
    required this.isActive,
    required super.child,
  });

  static bool isActiveOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PageActivityScope>()
            ?.isActive ??
        true;
  }

  @override
  bool updateShouldNotify(PageActivityScope oldWidget) {
    return isActive != oldWidget.isActive;
  }
}

class ItemPositionProvider extends InheritedWidget {
  final ItemPosition position;

  const ItemPositionProvider({
    super.key,
    required this.position,
    required super.child,
  });

  static ItemPositionProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ItemPositionProvider>();
  }

  @override
  bool updateShouldNotify(ItemPositionProvider oldWidget) =>
      position != oldWidget.position;
}

class BottomInsetScope extends InheritedWidget {
  static const double dockedSearchHeight = 48;
  static const double dockedSearchMargin = 16;
  static const double dockedSearchInset =
      dockedSearchMargin + dockedSearchHeight;

  const BottomInsetScope({
    super.key,
    required this.inset,
    required super.child,
  });

  final double inset;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomInsetScope>()?.inset ??
      0;

  @override
  bool updateShouldNotify(BottomInsetScope oldWidget) =>
      inset != oldWidget.inset;
}

class TopInsetScope extends InheritedWidget {
  const TopInsetScope({super.key, required this.inset, required super.child});

  final double? inset;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TopInsetScope>()?.inset;

  @override
  bool updateShouldNotify(TopInsetScope oldWidget) => inset != oldWidget.inset;
}

class FloatingBarScope extends InheritedWidget {
  const FloatingBarScope({
    super.key,
    required this.inset,
    required super.child,
  });

  final double inset;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FloatingBarScope>()?.inset;

  @override
  bool updateShouldNotify(FloatingBarScope oldWidget) =>
      inset != oldWidget.inset;
}

class ProxyDecoratorProvider extends InheritedWidget {
  const ProxyDecoratorProvider({
    super.key,
    required this.isProxyDecorator,
    required this.lift,
    required super.child,
  });

  final bool isProxyDecorator;
  final double lift;

  static ProxyDecoratorProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProxyDecoratorProvider>();

  @override
  bool updateShouldNotify(ProxyDecoratorProvider oldWidget) =>
      isProxyDecorator != oldWidget.isProxyDecorator || lift != oldWidget.lift;
}

class SheetOverhangScope extends InheritedWidget {
  const SheetOverhangScope({
    super.key,
    required this.overhang,
    this.fitsContent = false,
    required super.child,
  });

  final ValueListenable<double> overhang;
  final bool fitsContent;

  static ValueListenable<double>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SheetOverhangScope>()
      ?.overhang;

  static bool fillsDetentOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SheetOverhangScope>();
    return scope != null && !scope.fitsContent;
  }

  @override
  bool updateShouldNotify(SheetOverhangScope oldWidget) =>
      overhang != oldWidget.overhang || fitsContent != oldWidget.fitsContent;
}

typedef SheetDismissHandler = Future<void> Function();

class SheetDismissScope extends InheritedWidget {
  const SheetDismissScope({
    super.key,
    required this.handler,
    required super.child,
  });

  final ValueNotifier<SheetDismissHandler?> handler;

  static ValueNotifier<SheetDismissHandler?>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetDismissScope>()?.handler;

  @override
  bool updateShouldNotify(SheetDismissScope oldWidget) =>
      handler != oldWidget.handler;
}
