// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WoW QAddOns Manager';

  @override
  String get homeTitle => 'Dashboard';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLight => 'Light Theme';

  @override
  String get themeDark => 'Dark Theme';

  @override
  String get language => 'Language';

  @override
  String get scanTitle => 'Scan for Game Clients';

  @override
  String get noClientsFound =>
      'No WoW clients found. Please select directory manually.';

  @override
  String get clientDetailsTitle => 'Client Details';

  @override
  String get clientDetailsLoadingAddons => 'Loading installed addons...';

  @override
  String get clientDetailsLoadErrorTitle => 'Couldn\'t load installed addons';

  @override
  String clientDetailsLoadErrorMessage(Object details) {
    return 'The installed addons list couldn\'t be loaded: $details';
  }

  @override
  String get searchAddonsHint => 'Search addons...';

  @override
  String discoveryFeedTitle(Object version) {
    return 'Popular addons for $version';
  }

  @override
  String discoveryFeedSubtitle(Object version) {
    return 'This is a popularity feed from CurseForge for client version $version, not a text search result.';
  }

  @override
  String discoveryFeedLoading(Object version) {
    return 'Loading popular addons for $version...';
  }

  @override
  String get discoveryFeedErrorTitle =>
      'Couldn\'t load the popular addons feed';

  @override
  String discoveryFeedErrorMessage(Object version, Object details) {
    return 'Failed to load the popular addons feed for version $version: $details';
  }

  @override
  String get discoveryFeedEmptyTitle => 'No popular addons available';

  @override
  String discoveryFeedEmptyMessage(Object version) {
    return 'CurseForge didn\'t return a popular addons feed for client version $version.';
  }

  @override
  String searchResultsTitle(Object query) {
    return 'Results for \"$query\"';
  }

  @override
  String searchResultsSubtitle(Object version) {
    return 'Search results compatible with client version $version.';
  }

  @override
  String searchLoading(Object query) {
    return 'Searching for \"$query\"...';
  }

  @override
  String get searchErrorTitle => 'Search failed';

  @override
  String searchErrorMessage(Object details) {
    return 'The search request failed: $details';
  }

  @override
  String get searchNoResultsTitle => 'Nothing found';

  @override
  String searchNoResultsMessage(Object query, Object version) {
    return 'No addons found for \"$query\" for client version $version.';
  }

  @override
  String get retryButton => 'Retry';

  @override
  String addonAuthorLabel(Object author) {
    return 'By $author';
  }

  @override
  String addonVersionLabel(Object version) {
    return 'Ver: $version';
  }

  @override
  String get addonNoDescription => 'No description available';
}
