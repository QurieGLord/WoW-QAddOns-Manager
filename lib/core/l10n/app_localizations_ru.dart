// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'WoW QAddOns Менеджер';

  @override
  String get homeTitle => 'Панель управления';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get themeLight => 'Светлая тема';

  @override
  String get themeDark => 'Темная тема';

  @override
  String get language => 'Язык';

  @override
  String get scanTitle => 'Поиск игровых клиентов';

  @override
  String get noClientsFound =>
      'Клиенты WoW не найдены. Пожалуйста, выберите папку вручную.';
}
