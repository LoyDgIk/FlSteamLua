import '../../core/game_entry.dart';

enum StoreCategory {
  all(''),
  popular('topsellers'),
  newReleases('newreleases'),
  specials('specials'),
  comingSoon('comingsoon');

  const StoreCategory(this.filter);
  final String filter;
}

class StorePrice {
  const StorePrice({
    required this.currency,
    required this.initialMinor,
    required this.finalMinor,
    required this.discountPercent,
    required this.initialFormatted,
    required this.finalFormatted,
  });

  final String currency;
  final int initialMinor;
  final int finalMinor;
  final int discountPercent;
  final String initialFormatted;
  final String finalFormatted;
}

class StoreGame {
  const StoreGame({
    required this.appId,
    required this.name,
    required this.headerImage,
    this.priceText = '',
    this.releaseDate = '',
    this.platforms = const [],
    this.isFree = false,
    this.comingSoon = false,
  });

  final int appId;
  final String name;
  final String headerImage;
  final String priceText;
  final String releaseDate;
  final List<String> platforms;
  final bool isFree;
  final bool comingSoon;

  Uri get storeUri => Uri.https('store.steampowered.com', '/app/$appId/');

  GameEntry toGameEntry() =>
      GameEntry(appId: appId, name: name, coverUrl: headerImage);
}

class StoreGameDetails extends StoreGame {
  const StoreGameDetails({
    required super.appId,
    required super.name,
    required super.headerImage,
    super.priceText,
    super.releaseDate,
    super.platforms,
    super.isFree,
    super.comingSoon,
    this.description = '',
    this.type = 'game',
    this.website,
    this.price,
    this.dlcIds = const [],
    this.screenshots = const [],
    this.developers = const [],
    this.publishers = const [],
    this.genres = const [],
    this.achievementCount = 0,
    this.controllerSupport,
    this.requiredAge = 0,
  });

  final String description;
  final String type;
  final Uri? website;
  final StorePrice? price;
  final List<int> dlcIds;
  final List<String> screenshots;
  final List<String> developers;
  final List<String> publishers;
  final List<String> genres;
  final int achievementCount;
  final String? controllerSupport;
  final int requiredAge;
}

class StorePageResult {
  const StorePageResult({
    required this.items,
    required this.totalCount,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<StoreGame> items;
  final int totalCount;
  final int nextOffset;
  final bool hasMore;
}

class StoreException implements Exception {
  const StoreException(this.message, {this.statusCode, this.cause});
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

class StoreRequestCancelled implements Exception {
  const StoreRequestCancelled();

  @override
  String toString() => 'Store request cancelled';
}
