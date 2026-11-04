// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Desktop grouped-row adapter. SPDX-License-Identifier: GPL-3.0-only
part of 'list.dart';

class DecorationListItem extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? isSelected;
  final double? horizontalTitleGap;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onPressed;
  final double? minVerticalPadding;
  final bool invalid;
  final bool focusRing;

  const DecorationListItem({
    super.key,
    this.contentPadding,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.isSelected,
    this.onPressed,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.invalid = false,
    this.focusRing = true,
  });

  @override
  State<DecorationListItem> createState() => _DecorationListItemState();
}

class _DecorationListItemState extends State<DecorationListItem> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = ItemPositionProvider.of(context)?.position;
    final isStart = [
      ItemPosition.start,
      ItemPosition.startAndEnd,
    ].contains(position);
    final isEnd = [
      ItemPosition.end,
      ItemPosition.startAndEnd,
    ].contains(position);
    final borderRadius = AppRadius.vertical(
      top: isStart ? AppCorner.xl : AppCorner.none,
      bottom: isEnd ? AppCorner.xl : AppCorner.none,
    );
    final row = _ListRowSeparator(
      separated: !isEnd,
      emphasized: widget.invalid,
      states: _states,
      endIndent: 14,
      child: CommonCard(
        shape: AppShape.of(borderRadius),
        isError: widget.invalid,
        isSelected: widget.isSelected,
        padding: EdgeInsets.zero,
        statesController: _states,
        inert: widget.onPressed == null,
        focusRing: widget.focusRing,
        onPressed: widget.onPressed,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final tile = ListTile(
              leading: widget.leading,
              contentPadding:
                  widget.contentPadding ??
                  const EdgeInsets.only(right: 16, left: 16),
              title: _ListRowSeparatorStart(child: widget.title),
              subtitle: widget.subtitle,
              titleTextStyle: context.listTitleStyle,
              subtitleTextStyle: context.listSubtitleStyle,
              minVerticalPadding:
                  widget.minVerticalPadding ?? listRowVerticalPadding,
              minTileHeight: listRowMinHeight,
              horizontalTitleGap: widget.horizontalTitleGap,
              trailing: widget.trailing,
            );
            if (constraints.maxHeight >= double.infinity) {
              return tile;
            }
            return SizedBox(height: constraints.maxHeight, child: tile);
          },
        ),
      ),
    );
    return row;
  }
}

class SelectedDecorationListItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onSelected;
  final VoidCallback onPressed;
  final double? horizontalTitleGap;
  final Widget? leading;
  final bool invalid;
  final double? minVerticalPadding;

  const SelectedDecorationListItem({
    super.key,
    required this.isSelected,
    required this.onSelected,
    this.horizontalTitleGap,
    this.isEditing = false,
    this.invalid = false,
    required this.title,
    required this.onPressed,
    this.minVerticalPadding,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: title,
      minVerticalPadding: minVerticalPadding,
      contentPadding: const EdgeInsets.only(left: 16, right: 0),
      isSelected: isSelected,
      invalid: invalid,
      leading: leading,
      horizontalTitleGap: horizontalTitleGap,
      onPressed: () {
        if (isEditing) {
          onSelected();
          return;
        }
        onPressed();
      },
      subtitle: subtitle,
      trailing: CommonCheckBox(
        value: isSelected,
        isCircle: true,
        onChanged: (_) {
          onSelected();
        },
      ),
    );
  }
}
