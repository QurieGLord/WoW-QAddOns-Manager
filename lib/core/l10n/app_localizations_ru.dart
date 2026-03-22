// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Qddons Manager';

  @override
  String get homeTitle => 'Панель управления';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAppearanceTitle => 'Внешний вид';

  @override
  String get settingsAppearanceSubtitle =>
      'Режим темы, акцентная палитра и живой предпросмотр интерфейса.';

  @override
  String get settingsApplicationTitle => 'Приложение';

  @override
  String get settingsApplicationSubtitle =>
      'Только действительно полезные базовые параметры.';

  @override
  String get settingsAboutTitle => 'О приложении';

  @override
  String get settingsAboutSubtitle => 'Бренд, версия и ссылки на проект.';

  @override
  String get themeLight => 'Светлая тема';

  @override
  String get themeDark => 'Темная тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get language => 'Язык';

  @override
  String get settingsThemeModeTitle => 'Режим темы';

  @override
  String get settingsThemeModeSubtitle =>
      'Выберите, как Qddons Manager должен выглядеть на светлых и тёмных поверхностях.';

  @override
  String get settingsAccentTitle => 'Акцентная палитра';

  @override
  String get settingsAccentSubtitle =>
      'Выберите базовый цвет, который задаёт весь выразительный стиль интерфейса.';

  @override
  String get settingsAccentCoral => 'Коралл';

  @override
  String get settingsAccentLagoon => 'Лагуна';

  @override
  String get settingsAccentGrove => 'Роща';

  @override
  String get settingsAccentEmber => 'Уголь';

  @override
  String get settingsAccentOrchid => 'Орхидея';

  @override
  String get settingsAccentTide => 'Прилив';

  @override
  String get settingsPreviewTitle => 'Живой предпросмотр';

  @override
  String get settingsPreviewSubtitle =>
      'Небольшой превью-фрагмент, показывающий настроение дэшборда.';

  @override
  String get settingsPreviewWindowTitle => 'Предпросмотр дэшборда';

  @override
  String get settingsPreviewClientName => 'Battle for Azeroth (8.3.7)';

  @override
  String get settingsLanguageTitle => 'Язык приложения';

  @override
  String get settingsLanguageSubtitle =>
      'Язык интерфейса меняется сразу после выбора.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsPreviewChip => 'Синхронизация аддонов';

  @override
  String get settingsPreviewAction => 'Открыть клиент';

  @override
  String get aboutTagline =>
      'Универсальное управление аддонами для любой эпохи WoW.';

  @override
  String get aboutVersionTitle => 'Версия';

  @override
  String get aboutDeveloperTitle => 'Разработчик';

  @override
  String get aboutSupportTitle => 'Поддержать проект';

  @override
  String get aboutSupportSubtitle =>
      'Следите за разработкой, сообщайте о проблемах или угостите автора кофе.';

  @override
  String get aboutOpenGitHub => 'Открыть GitHub';

  @override
  String get aboutOpenBoosty => 'Поддержать на Boosty';

  @override
  String get externalLinkErrorMessage => 'Не удалось открыть внешнюю ссылку.';

  @override
  String get dashboardManageAddons => 'Управление аддонами';

  @override
  String get dashboardRenameClient => 'Переименовать клиент';

  @override
  String get dashboardClientLocation => 'Расположение';

  @override
  String get dashboardClientTypeRetail => 'Retail';

  @override
  String get dashboardClientTypeClassic => 'Classic';

  @override
  String get dashboardClientTypePtr => 'PTR';

  @override
  String get dashboardClientTypeLegacy => 'Legacy';

  @override
  String get dashboardClientTypeUnknown => 'Неизвестно';

  @override
  String get scanTitle => 'Поиск игровых клиентов';

  @override
  String get noClientsFound =>
      'Клиенты WoW не найдены. Пожалуйста, выберите папку вручную.';

  @override
  String get clientDetailsTitle => 'Сведения о клиенте';

  @override
  String get clientLaunchAction => 'Запустить игру';

  @override
  String get clientLaunchMissingExecutable =>
      'Для этого клиента не удалось найти исполняемый файл игры.';

  @override
  String get clientLaunchInvalidPath =>
      'Папка клиента недоступна или больше не существует.';

  @override
  String get clientLaunchFailed => 'Не удалось запустить игровой клиент.';

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
    return 'Это подборка популярных аддонов из доступных источников для версии клиента $version, а не результаты текстового поиска.';
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
    return 'Доступные источники не вернули подборку популярных аддонов для версии клиента $version.';
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

  @override
  String get addonDetailsGalleryTitle => 'Скриншоты';

  @override
  String get addonDetailsDescriptionTitle => 'Описание';

  @override
  String get addonDetailsClose => 'Закрыть';
}
