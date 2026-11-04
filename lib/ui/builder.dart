// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/widgets.dart';

class WidthBuilder extends StatefulWidget {
  const WidthBuilder({super.key, required this.builder});

  final ValueWidgetBuilder<double> builder;

  @override
  State<WidthBuilder> createState() => _WidthBuilderState();
}

class _WidthBuilderState extends State<WidthBuilder> {
  double? _width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width != _width) {
          _width = width;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _width != null) {
              setState(() {});
            }
          });
        }
        return widget.builder(context, width, null);
      },
    );
  }
}
