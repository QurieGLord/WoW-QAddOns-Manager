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
  /// **'WoW QAddOns Manager'**
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

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

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
