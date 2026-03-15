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
}
