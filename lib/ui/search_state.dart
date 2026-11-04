import 'package:flutter/foundation.dart';

class AppBarSearchState {
  const AppBarSearchState({required this.onSearch, this.query});

  final ValueChanged<String> onSearch;
  final String? query;

  AppBarSearchState copyWith({String? query, bool clearQuery = false}) =>
      AppBarSearchState(
        onSearch: onSearch,
        query: clearQuery ? null : query ?? this.query,
      );

  @override
  bool operator ==(Object other) =>
      other is AppBarSearchState &&
      other.onSearch == onSearch &&
      other.query == query;

  @override
  int get hashCode => Object.hashAll([onSearch, query]);
}
