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

  @override
  String get clientDetailsTitle => 'Сведения о клиенте';

  @override
  String get clientDetailsLoadingAddons => 'Загрузка установленных аддонов...';

  @override
  String get clientDetailsLoadErrorTitle =>
      'Не удалось загрузить установленные аддоны';

  @override
  String clientDetailsLoadErrorMessage(Object details) {
    return 'Не удалось загрузить список установленных аддонов: $details';
  }

  @override
  String get searchAddonsHint => 'Поиск аддонов...';

  @override
  String discoveryFeedTitle(Object version) {
    return 'Популярные аддоны для версии $version';
  }

  @override
  String discoveryFeedSubtitle(Object version) {
    return 'Это подборка популярных аддонов из CurseForge для версии клиента $version, а не результаты текстового поиска.';
  }

  @override
  String discoveryFeedLoading(Object version) {
    return 'Загрузка популярных аддонов для версии $version...';
  }

  @override
  String get discoveryFeedErrorTitle =>
      'Не удалось загрузить подборку популярных аддонов';

  @override
  String discoveryFeedErrorMessage(Object version, Object details) {
    return 'Не удалось получить подборку популярных аддонов для версии $version: $details';
  }

  @override
  String get discoveryFeedEmptyTitle => 'Популярные аддоны не найдены';

  @override
  String discoveryFeedEmptyMessage(Object version) {
    return 'CurseForge не вернул подборку популярных аддонов для версии клиента $version.';
  }

  @override
  String searchResultsTitle(Object query) {
    return 'Результаты для «$query»';
  }

  @override
  String searchResultsSubtitle(Object version) {
    return 'Результаты поиска, совместимые с версией клиента $version.';
  }

  @override
  String searchLoading(Object query) {
    return 'Поиск по запросу «$query»...';
  }

  @override
  String get searchErrorTitle => 'Не удалось выполнить поиск';

  @override
  String searchErrorMessage(Object details) {
    return 'Запрос поиска завершился ошибкой: $details';
  }

  @override
  String get searchNoResultsTitle => 'Ничего не найдено';

  @override
  String searchNoResultsMessage(Object query, Object version) {
    return 'Для запроса «$query» и версии клиента $version аддоны не найдены.';
  }

  @override
  String get retryButton => 'Повторить';

  @override
  String addonAuthorLabel(Object author) {
    return 'Автор: $author';
  }

  @override
  String addonVersionLabel(Object version) {
    return 'Версия: $version';
  }

  @override
  String get addonNoDescription => 'Описание отсутствует';
}
