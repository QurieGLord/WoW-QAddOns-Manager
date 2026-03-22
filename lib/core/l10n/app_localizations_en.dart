// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Qddons Manager';

  @override
  String get homeTitle => 'Dashboard';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsAppearanceSubtitle =>
      'Theme mode, accent palette and a live preview surface.';

  @override
  String get settingsApplicationTitle => 'Application';

  @override
  String get settingsApplicationSubtitle =>
      'Only the essentials that matter right now.';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'Brand, version and project links.';

  @override
  String get themeLight => 'Light Theme';

  @override
  String get themeDark => 'Dark Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get language => 'Language';

  @override
  String get settingsThemeModeTitle => 'Theme mode';

  @override
  String get settingsThemeModeSubtitle =>
      'Choose how Qddons Manager reacts to light and dark surfaces.';

  @override
  String get settingsAccentTitle => 'Accent palette';

  @override
  String get settingsAccentSubtitle =>
      'Pick the seed color that drives the whole expressive system.';

  @override
  String get settingsAccentCoral => 'Coral';

  @override
  String get settingsAccentLagoon => 'Lagoon';

  @override
  String get settingsAccentGrove => 'Grove';

  @override
  String get settingsAccentEmber => 'Ember';

  @override
  String get settingsAccentOrchid => 'Orchid';

  @override
  String get settingsAccentTide => 'Tide';

  @override
  String get settingsPreviewTitle => 'Live preview';

  @override
  String get settingsPreviewSubtitle =>
      'A compact preview of how the dashboard will feel.';

  @override
  String get settingsPreviewWindowTitle => 'Dashboard preview';

  @override
  String get settingsPreviewClientName => 'Battle for Azeroth (8.3.7)';

  @override
  String get settingsLanguageTitle => 'App language';

  @override
  String get settingsLanguageSubtitle =>
      'This changes the application language immediately.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Russian';

  @override
  String get settingsPreviewChip => 'Addon sync';

  @override
  String get settingsPreviewAction => 'Open client';

  @override
  String get aboutTagline => 'Universal addon management for every WoW era.';

  @override
  String get aboutVersionTitle => 'Version';

  @override
  String get aboutDeveloperTitle => 'Developer';

  @override
  String get aboutSupportTitle => 'Support the project';

  @override
  String get aboutSupportSubtitle =>
      'Follow development, report issues or buy me a coffee.';

  @override
  String get aboutOpenGitHub => 'Open GitHub';

  @override
  String get aboutOpenBoosty => 'Support on Boosty';

  @override
  String get externalLinkErrorMessage => 'Couldn\'t open the external link.';

  @override
  String get dashboardManageAddons => 'Manage addons';

  @override
  String get dashboardRenameClient => 'Rename client';

  @override
  String get dashboardClientLocation => 'Location';

  @override
  String get dashboardClientTypeRetail => 'Retail';

  @override
  String get dashboardClientTypeClassic => 'Classic';

  @override
  String get dashboardClientTypePtr => 'PTR';

  @override
  String get dashboardClientTypeLegacy => 'Legacy';

  @override
  String get dashboardClientTypeUnknown => 'Unknown';

  @override
  String get scanTitle => 'Scan for Game Clients';

  @override
  String get noClientsFound =>
      'No WoW clients found. Please select directory manually.';

  @override
  String get clientDetailsTitle => 'Client Details';

  @override
  String get clientLaunchAction => 'Launch game';

  @override
  String get clientLaunchMissingExecutable =>
      'The game executable couldn\'t be found for this client.';

  @override
  String get clientLaunchInvalidPath =>
      'The client folder is unavailable or no longer exists.';

  @override
  String get clientLaunchFailed => 'Couldn\'t launch the game client.';

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
    return 'This is a popularity feed from the available addon sources for client version $version, not a text search result.';
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
    return 'The available addon sources didn\'t return a popular addons feed for client version $version.';
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
  String get elvuiVerifiedExactClassification => 'Verified exact match';

  @override
  String get elvuiVerifiedBranchClassification =>
      'Verified branch-compatible build';

  @override
  String get elvuiNotVerifiedClassification => 'Not verified';

  @override
  String get elvuiNotVerifiedAction => 'Not verified';

  @override
  String elvuiNotVerifiedForVersion(Object version) {
    return 'ElvUI is not yet verified for client version $version.';
  }

  @override
  String get addonNoDescription => 'No description available';

  @override
  String get addonDetailsGalleryTitle => 'Screenshots';

  @override
  String get addonDetailsDescriptionTitle => 'Description';

  @override
  String get addonDetailsClose => 'Close';
}
