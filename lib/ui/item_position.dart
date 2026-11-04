// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Desktop grouped-row adapter. SPDX-License-Identifier: GPL-3.0-only
enum ItemPosition {
  start,
  middle,
  end,
  startAndEnd;

  static ItemPosition get(int index, int length) {
    ItemPosition position = ItemPosition.middle;
    if (length == 1) {
      position = ItemPosition.startAndEnd;
    } else if (index == length - 1) {
      position = ItemPosition.end;
    } else if (index == 0) {
      position = ItemPosition.start;
    }
    return position;
  }
}
