import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Qddons Manager'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homeTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode, accent palette and a live preview surface.'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsApplicationTitle;

  /// No description provided for @settingsApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only the essentials that matter right now.'**
  String get settingsApplicationSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Brand, version and project links.'**
  String get settingsAboutSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @settingsThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeModeTitle;

  /// No description provided for @settingsThemeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how Qddons Manager reacts to light and dark surfaces.'**
  String get settingsThemeModeSubtitle;

  /// No description provided for @settingsAccentTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent palette'**
  String get settingsAccentTitle;

  /// No description provided for @settingsAccentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the seed color that drives the whole expressive system.'**
  String get settingsAccentSubtitle;

  /// No description provided for @settingsAccentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get settingsAccentCoral;

  /// No description provided for @settingsAccentLagoon.
  ///
  /// In en, this message translates to:
  /// **'Lagoon'**
  String get settingsAccentLagoon;

  /// No description provided for @settingsAccentGrove.
  ///
  /// In en, this message translates to:
  /// **'Grove'**
  String get settingsAccentGrove;

  /// No description provided for @settingsAccentEmber.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get settingsAccentEmber;

  /// No description provided for @settingsAccentOrchid.
  ///
  /// In en, this message translates to:
  /// **'Orchid'**
  String get settingsAccentOrchid;

  /// No description provided for @settingsAccentTide.
  ///
  /// In en, this message translates to:
  /// **'Tide'**
  String get settingsAccentTide;

  /// No description provided for @settingsPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get settingsPreviewTitle;

  /// No description provided for @settingsPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A compact preview of how the dashboard will feel.'**
  String get settingsPreviewSubtitle;

  /// No description provided for @settingsPreviewWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard preview'**
  String get settingsPreviewWindowTitle;

  /// No description provided for @settingsPreviewClientName.
  ///
  /// In en, this message translates to:
  /// **'Battle for Azeroth (8.3.7)'**
  String get settingsPreviewClientName;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This changes the application language immediately.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get settingsLanguageRussian;

  /// No description provided for @settingsPreviewChip.
  ///
  /// In en, this message translates to:
  /// **'Addon sync'**
  String get settingsPreviewChip;

  /// No description provided for @settingsPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Open client'**
  String get settingsPreviewAction;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Universal addon management for every WoW era.'**
  String get aboutTagline;

  /// No description provided for @aboutVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionTitle;

  /// No description provided for @aboutDeveloperTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloperTitle;

  /// No description provided for @aboutSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support the project'**
  String get aboutSupportTitle;

  /// No description provided for @aboutSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow development, report issues or buy me a coffee.'**
  String get aboutSupportSubtitle;

  /// No description provided for @aboutOpenGitHub.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub'**
  String get aboutOpenGitHub;

  /// No description provided for @aboutOpenBoosty.
  ///
  /// In en, this message translates to:
  /// **'Support on Boosty'**
  String get aboutOpenBoosty;

  /// No description provided for @externalLinkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the external link.'**
  String get externalLinkErrorMessage;

  /// No description provided for @dashboardManageAddons.
  ///
  /// In en, this message translates to:
  /// **'Manage addons'**
  String get dashboardManageAddons;

  /// No description provided for @dashboardRenameClient.
  ///
  /// In en, this message translates to:
  /// **'Rename client'**
  String get dashboardRenameClient;

  /// No description provided for @dashboardClientLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get dashboardClientLocation;

  /// No description provided for @dashboardClientTypeRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get dashboardClientTypeRetail;

  /// No description provided for @dashboardClientTypeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get dashboardClientTypeClassic;

  /// No description provided for @dashboardClientTypePtr.
  ///
  /// In en, this message translates to:
  /// **'PTR'**
  String get dashboardClientTypePtr;

  /// No description provided for @dashboardClientTypeLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get dashboardClientTypeLegacy;

  /// No description provided for @dashboardClientTypeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get dashboardClientTypeUnknown;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan for Game Clients'**
  String get scanTitle;

  /// No description provided for @noClientsFound.
  ///
  /// In en, this message translates to:
  /// **'No WoW clients found. Please select directory manually.'**
  String get noClientsFound;

  /// No description provided for @clientDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Client Details'**
  String get clientDetailsTitle;

  /// No description provided for @clientLaunchAction.
  ///
  /// In en, this message translates to:
  /// **'Launch game'**
  String get clientLaunchAction;

  /// No description provided for @clientLaunchMissingExecutable.
  ///
  /// In en, this message translates to:
  /// **'The game executable couldn\'t be found for this client.'**
  String get clientLaunchMissingExecutable;

  /// No description provided for @clientLaunchInvalidPath.
  ///
  /// In en, this message translates to:
  /// **'The client folder is unavailable or no longer exists.'**
  String get clientLaunchInvalidPath;

  /// No description provided for @clientLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t launch the game client.'**
  String get clientLaunchFailed;

  /// No description provided for @clientDetailsLoadingAddons.
  ///
  /// In en, this message translates to:
  /// **'Loading installed addons...'**
  String get clientDetailsLoadingAddons;

  /// No description provided for @clientDetailsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load installed addons'**
  String get clientDetailsLoadErrorTitle;

  /// No description provided for @clientDetailsLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The installed addons list couldn\'t be loaded: {details}'**
  String clientDetailsLoadErrorMessage(Object details);

  /// No description provided for @searchAddonsHint.
  ///
  /// In en, this message translates to:
  /// **'Search addons...'**
  String get searchAddonsHint;

  /// No description provided for @discoveryFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular addons for {version}'**
  String discoveryFeedTitle(Object version);

  /// No description provided for @discoveryFeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is a popularity feed from the available addon sources for client version {version}, not a text search result.'**
  String discoveryFeedSubtitle(Object version);

  /// No description provided for @discoveryFeedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading popular addons for {version}...'**
  String discoveryFeedLoading(Object version);

  /// No description provided for @discoveryFeedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the popular addons feed'**
  String get discoveryFeedErrorTitle;

  /// No description provided for @discoveryFeedErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the popular addons feed for version {version}: {details}'**
  String discoveryFeedErrorMessage(Object version, Object details);

  /// No description provided for @discoveryFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No popular addons available'**
  String get discoveryFeedEmptyTitle;

  /// No description provided for @discoveryFeedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The available addon sources didn\'t return a popular addons feed for client version {version}.'**
  String discoveryFeedEmptyMessage(Object version);

  /// No description provided for @searchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String searchResultsTitle(Object query);

  /// No description provided for @searchResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search results compatible with client version {version}.'**
  String searchResultsSubtitle(Object version);

  /// No description provided for @searchLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching for \"{query}\"...'**
  String searchLoading(Object query);

  /// No description provided for @searchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchErrorTitle;

  /// No description provided for @searchErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The search request failed: {details}'**
  String searchErrorMessage(Object details);

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No addons found for \"{query}\" for client version {version}.'**
  String searchNoResultsMessage(Object query, Object version);

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @addonAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'By {author}'**
  String addonAuthorLabel(Object author);

  /// No description provided for @addonVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Ver: {version}'**
  String addonVersionLabel(Object version);

  /// No description provided for @addonNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available'**
  String get addonNoDescription;

  /// No description provided for @addonDetailsGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get addonDetailsGalleryTitle;

  /// No description provided for @addonDetailsDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addonDetailsDescriptionTitle;

  /// No description provided for @addonDetailsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get addonDetailsClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
