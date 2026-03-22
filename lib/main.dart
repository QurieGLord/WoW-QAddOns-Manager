import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';
import 'package:wow_qaddons_manager/core/l10n/app_localizations.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/core/theme/app_theme.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/data/services/addon_identity_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_installer_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_feed_state.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';
import 'package:wow_qaddons_manager/features/addons/local/presentation/local_addons_providers.dart';
import 'package:wow_qaddons_manager/features/addons/search/application/search_use_cases.dart';
import 'package:wow_qaddons_manager/features/addons/search/presentation/search_providers.dart';
import 'package:wow_qaddons_manager/features/clients/application/client_use_cases.dart';
import 'package:wow_qaddons_manager/features/clients/presentation/client_providers.dart';
import 'package:wow_qaddons_manager/features/settings/presentation/settings_providers.dart';
import 'package:wow_qaddons_manager/shared/widgets/app_logo_widget.dart';
import 'package:wow_qaddons_manager/shared/widgets/performance_tracked_scope.dart';

const bool kShowPerformanceOverlay = bool.fromEnvironment(
  'SHOW_PERFORMANCE_OVERLAY',
);
const String kAppVersionLabel = '1.0.0';
final Uri kProjectGitHubUri = Uri.parse(
  'https://github.com/QurieGLord/WoW-QAddOns-Manager',
);
final Uri kProjectBoostyUri = Uri.parse('https://boosty.to/qurieglord');
const String kClientCardAssetsRoot = 'assets/client_cards';
const String kClientIconAssetsRoot = 'assets/client_icons';
const Alignment kClientBannerArtAlignment = Alignment(0, -0.46);
const Alignment kClientBannerArtCompactAlignment = Alignment(0, -0.58);
const CustomMouseWheelScrollConfig kDesktopMouseWheelScrollConfig =
    CustomMouseWheelScrollConfig(
      scrollAmountMultiplier: 2.15,
      scrollDuration: Duration(milliseconds: 300),
      scrollCurve: Curves.easeOutQuart,
      mouseWheelTurnsThrottleTimeMs: 24,
    );

enum _ClientBannerVariant { full, medium, small }

enum _ClientBannerUsage { compactCard, mediumHero, largeHeader }

String _clientBannerAssetPath(
  String slot, [
  _ClientBannerVariant variant = _ClientBannerVariant.full,
]) {
  final fileName = switch (variant) {
    _ClientBannerVariant.full => 'banner.png',
    _ClientBannerVariant.medium => 'banner-medium.png',
    _ClientBannerVariant.small => 'banner-small.png',
  };

  return '$kClientCardAssetsRoot/$slot/$fileName';
}

List<String> _clientBannerAssetCandidates(
  String slot,
  _ClientBannerUsage usage,
) {
  final preferredPath = switch (usage) {
    _ClientBannerUsage.compactCard => _clientBannerAssetPath(
      slot,
      _ClientBannerVariant.small,
    ),
    _ClientBannerUsage.mediumHero => _clientBannerAssetPath(
      slot,
      _ClientBannerVariant.medium,
    ),
    _ClientBannerUsage.largeHeader => _clientBannerAssetPath(slot),
  };
  final fallbackPath = _clientBannerAssetPath(slot);

  if (preferredPath == fallbackPath) {
    return <String>[fallbackPath];
  }

  return <String>[preferredPath, fallbackPath];
}

String _clientIconAssetPath(String slot) =>
    '$kClientIconAssetsRoot/$slot/icon.svg';

class AppIcons {
  static const IconData appearance = Icons.palette_outlined;
  static const IconData application = Icons.widgets_outlined;
  static const IconData info = Icons.info_rounded;
}

class _QddonsDesktopScrollBehavior extends MaterialScrollBehavior {
  const _QddonsDesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    switch (platform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return super.getScrollPhysics(context);
    }
  }
}

bool _shouldUseDesktopImprovedScrolling() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.iOS:
      return false;
  }
}

class _DesktopImprovedScrolling extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const _DesktopImprovedScrolling({
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!_shouldUseDesktopImprovedScrolling()) {
      return child;
    }

    return ImprovedScrolling(
      scrollController: controller,
      enableKeyboardScrolling: true,
      enableCustomMouseWheelScrolling: true,
      keyboardScrollConfig: const KeyboardScrollConfig(
        arrowsScrollAmount: 180,
        arrowsScrollDuration: Duration(milliseconds: 180),
        pageUpDownScrollAmount: 560,
        pageUpDownScrollDuration: Duration(milliseconds: 240),
        spaceScrollAmount: 640,
        spaceScrollDuration: Duration(milliseconds: 260),
        defaultHomeEndScrollDuration: Duration(milliseconds: 360),
        scrollCurve: Curves.easeOutCubic,
      ),
      customMouseWheelScrollConfig: kDesktopMouseWheelScrollConfig,
      child: child,
    );
  }
}

class _DesktopScrollHost extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    ScrollPhysics? physics,
  )
  builder;

  const _DesktopScrollHost({required this.builder});

  @override
  State<_DesktopScrollHost> createState() => _DesktopScrollHostState();
}

class _DesktopScrollHostState extends State<_DesktopScrollHost> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usesImprovedScrolling = _shouldUseDesktopImprovedScrolling();
    final physics = usesImprovedScrolling
        ? const NeverScrollableScrollPhysics()
        : null;
    final child = widget.builder(context, _controller, physics);

    if (!usesImprovedScrolling) {
      return child;
    }

    return _DesktopImprovedScrolling(controller: _controller, child: child);
  }
}

// Localization Stub
class AppLocalizationsStub {
  static String appTitle(String locale) => 'Qddons Manager';
  static String homeTitle(String locale) =>
      locale == 'ru' ? 'Клиенты WoW' : 'WoW Clients';
  static String settingsTitle(String locale) =>
      locale == 'ru' ? 'Настройки' : 'Settings';
  static String interfaceSection(String locale) =>
      locale == 'ru' ? 'Внешний вид' : 'Appearance';
  static String languageSection(String locale) =>
      locale == 'ru' ? 'Язык' : 'Language';
  static String themeModeLabel(String locale) =>
      locale == 'ru' ? 'Тема оформления' : 'Theme Mode';
  static String colorSchemeLabel(String locale) =>
      locale == 'ru' ? 'Цветовая схема' : 'Color Scheme';
  static String wowClientsSection(String locale) =>
      locale == 'ru' ? 'Приложение' : 'Application';
  static String downloadsSection(String locale) =>
      locale == 'ru' ? 'Приложение' : 'Application';
  static String aboutSection(String locale) =>
      locale == 'ru' ? 'О приложении' : 'About';
  static String versionLabel(String locale) =>
      locale == 'ru' ? 'Версия' : 'Version';
  static String developerLabel(String locale) =>
      locale == 'ru' ? 'Разработчик' : 'Developer';
  static String descriptionLabel(String locale) =>
      locale == 'ru' ? 'Управляйте своими аддонами' : 'Manage your addons';
  static String scanFailed(String locale) =>
      locale == 'ru' ? 'Клиент WoW не найден' : 'WoW client not found';

  static String missingDataFolder(String locale) => locale == 'ru'
      ? 'В папке отсутствует директория "Data"'
      : 'Folder "Data" is missing';
  static String missingExeFile(String locale) => locale == 'ru'
      ? 'Исполняемый файл (.exe) не найден'
      : 'Executable file (.exe) not found';
  static String selectVersionTitle(String locale) =>
      locale == 'ru' ? 'Выберите версию игры' : 'Select Game Version';

  static String scanSuccess(String locale, String ver) =>
      locale == 'ru' ? 'Добавлен: $ver' : 'Added: $ver';
  static String manageAddons(String locale) =>
      locale == 'ru' ? 'Управление аддонами' : 'Manage Addons';
  static String emptyClients(String locale) =>
      locale == 'ru' ? 'Список клиентов пуст' : 'No clients found';
  static String searchAddons(String locale) =>
      locale == 'ru' ? 'Поиск аддонов...' : 'Search addons...';
  static String installing(String locale) =>
      locale == 'ru' ? 'Установка...' : 'Installing...';
  static String install(String locale) =>
      locale == 'ru' ? 'Установить' : 'Install';
  static String installed(String locale) =>
      locale == 'ru' ? 'Установлено' : 'Installed';
  static String versionNotFound(String locale, String version) => locale == 'ru'
      ? 'Файл не найден для версии $version (или совместимой)'
      : 'No file found for version $version (or compatible)';
  static String installSuccess(String locale) => locale == 'ru'
      ? 'Аддон успешно установлен'
      : 'Addon installed successfully';
  static String alreadyInstalled(String locale, String name) => locale == 'ru'
      ? 'Аддон уже установлен: $name'
      : 'Addon is already installed: $name';
  static String installError(String locale) =>
      locale == 'ru' ? 'Ошибка' : 'Error';
  static String myAddons(String locale) =>
      locale == 'ru' ? 'Мои аддоны' : 'My Addons';
  static String delete(String locale) => locale == 'ru' ? 'Удалить' : 'Delete';
  static String confirmDeleteTitle(String locale) =>
      locale == 'ru' ? 'Удалить аддон?' : 'Delete addon?';
  static String confirmDeleteMessage(String locale, String name) =>
      locale == 'ru'
      ? 'Вы уверены, что хотите удалить $name?'
      : 'Are you sure you want to delete $name?';
  static String cancel(String locale) => locale == 'ru' ? 'Отмена' : 'Cancel';
  static String noLocalAddons(String locale) => locale == 'ru'
      ? 'Установленные аддоны не найдены'
      : 'No installed addons found';
  static String scanAddons(String locale) =>
      locale == 'ru' ? 'Сканировать' : 'Scan';
  static String refreshAddons(String locale) =>
      locale == 'ru' ? 'Обновить список' : 'Refresh list';
  static String importAddon(String locale) =>
      locale == 'ru' ? 'Импортировать аддон' : 'Import addon';
  static String installFromArchive(String locale) =>
      locale == 'ru' ? 'Установить из архива' : 'Install from archive';
  static String selectAll(String locale) =>
      locale == 'ru' ? 'Выбрать всё' : 'Select all';
  static String clearAll(String locale) =>
      locale == 'ru' ? 'Снять всё' : 'Clear all';
  static String deleteSelected(String locale) =>
      locale == 'ru' ? 'Удалить выбранные' : 'Delete selected';
  static String selectedCount(String locale, int count) =>
      locale == 'ru' ? 'Выбрано: $count' : 'Selected: $count';
  static String addonFolders(String locale, int count) =>
      locale == 'ru' ? 'Папок: $count' : 'Folders: $count';
  static String localManual(String locale) =>
      locale == 'ru' ? 'Вручную' : 'Manual';
  static String clearSelection(String locale) =>
      locale == 'ru' ? 'Снять выбор' : 'Clear selection';
  static String loadMore(String locale) =>
      locale == 'ru' ? 'Загрузить ещё' : 'Load more';
  static String renameClient(String locale) =>
      locale == 'ru' ? 'Переименовать клиент' : 'Rename client';
  static String clientNameHint(String locale) =>
      locale == 'ru' ? 'Введите имя клиента' : 'Enter client name';
  static String resetToDefault(String locale) =>
      locale == 'ru' ? 'Сбросить к умолчанию' : 'Reset to default';
  static String save(String locale) => locale == 'ru' ? 'Сохранить' : 'Save';
  static String replace(String locale) =>
      locale == 'ru' ? 'Заменить' : 'Replace';
  static String replaceFoldersTitle(String locale) => locale == 'ru'
      ? 'Заменить существующие папки?'
      : 'Replace existing folders?';
  static String replaceFoldersMessage(String locale, String folders) =>
      locale == 'ru'
      ? 'Следующие папки уже существуют и будут заменены: $folders'
      : 'The following folders already exist and will be replaced: $folders';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('ENV file not found or failed to load: $e');
  }

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(sharedPrefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: kShowPerformanceOverlay,
      scrollBehavior: const _QddonsDesktopScrollBehavior(),
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Qddons Manager',
      themeMode: settings.themeMode,
      theme: AppTheme.createTheme(Brightness.light, settings.seedColor),
      darkTheme: AppTheme.createTheme(Brightness.dark, settings.seedColor),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleScan(
    BuildContext context,
    WidgetRef ref,
    String locale,
  ) async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: locale == 'ru'
          ? 'Выберите папку с World of Warcraft'
          : 'Select World of Warcraft folder',
    );

    if (directoryPath == null) return;

    final scanWowClients = ref.read(scanWowClientsUseCaseProvider);

    List<GameClient> clients;
    try {
      clients = await scanWowClients(directoryPath);
    } catch (e) {
      if (!context.mounted) return;

      String errorMsg = AppLocalizationsStub.scanFailed(locale);
      final eStr = e.toString();

      if (eStr.contains('MISSING_DATA')) {
        errorMsg = AppLocalizationsStub.missingDataFolder(locale);
      } else if (eStr.contains('MISSING_EXE')) {
        errorMsg = AppLocalizationsStub.missingExeFile(locale);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizationsStub.scanFailed(locale)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    GameClient? selectedClient;

    if (clients.length == 1) {
      selectedClient = clients.first;
    } else {
      selectedClient = await showDialog<GameClient>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            locale == 'ru' ? 'Выберите файл запуска' : 'Select executable',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(clients[index].executableName ?? 'wow.exe'),
                subtitle: Text(clients[index].version),
                onTap: () => Navigator.pop(context, clients[index]),
              ),
            ),
          ),
        ),
      );
    }

    if (selectedClient == null || !context.mounted) return;

    if (selectedClient.version == 'Unknown') {
      final String? manualVersion = await showDialog<String>(
        context: context,
        builder: (context) => _VersionSelectionDialog(locale: locale),
      );

      if (manualVersion != null) {
        final inferredType = GameClient.inferTypeForVersion(
          manualVersion,
          productCode: selectedClient.productCode,
          fallbackType: selectedClient.type,
        );
        selectedClient = selectedClient.copyWith(
          version: manualVersion,
          type: inferredType,
        );
      } else {
        return;
      }
    }

    await ref.read(clientListProvider.notifier).addClient(selectedClient);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizationsStub.scanSuccess(locale, selectedClient.version),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final locale = settings.locale.languageCode;
    final l10n = AppLocalizations.of(context)!;
    final clients = ref.watch(clientListProvider);

    return PerformanceTrackedScope(
      screenName: 'Home',
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(l10n.appTitle),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HomeBoostyPillButton(
                  label: l10n.aboutOpenBoosty,
                  onPressed: () =>
                      _openExternalLink(context, kProjectBoostyUri),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _HomeAppBarIconButton(
                tooltip: l10n.settingsTitle,
                icon: Icons.settings_outlined,
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const SettingsScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: clients.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogoWidget(size: 160),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizationsStub.emptyClients(locale),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              )
            : _DesktopScrollHost(
                builder: (context, controller, physics) => GridView.builder(
                  controller: controller,
                  physics: physics,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  addRepaintBoundaries: false,
                  addAutomaticKeepAlives: false,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 312,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: clients.length,
                  itemBuilder: (context, index) => RepaintBoundary(
                    child: _ClientCard(client: clients[index]),
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _handleScan(context, ref, locale),
          icon: const Icon(Icons.add_rounded),
          label: Text(locale == 'ru' ? 'Добавить клиент' : 'Add Client'),
        ),
      ),
    );
  }
}

class _VersionSelectionDialog extends StatelessWidget {
  final String locale;
  const _VersionSelectionDialog({required this.locale});

  @override
  Widget build(BuildContext context) {
    final versions = [
      '1.12.1',
      '2.4.3',
      '3.3.5',
      '4.3.4',
      '5.4.8',
      '6.2.4',
      '7.3.5',
      '8.3.7',
      '9.2.7',
      '10.2.7',
      '11.0.0',
    ];

    return AlertDialog(
      title: Text(AppLocalizationsStub.selectVersionTitle(locale)),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: versions.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(versions[index]),
            onTap: () => Navigator.pop(context, versions[index]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizationsStub.cancel(locale)),
        ),
      ],
    );
  }
}

class _ClientRenameDialogResult {
  final String? customName;
  final bool resetToDefault;

  const _ClientRenameDialogResult({
    this.customName,
    this.resetToDefault = false,
  });
}

Future<GameClient?> _promptRenameClient(
  BuildContext context,
  WidgetRef ref,
  GameClient client,
  String locale,
) async {
  final controller = TextEditingController(
    text: client.customDisplayName ?? '',
  );
  final result = await showDialog<_ClientRenameDialogResult>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizationsStub.renameClient(locale)),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: AppLocalizationsStub.clientNameHint(locale),
          helperText: client.defaultDisplayName,
        ),
        onSubmitted: (value) => Navigator.pop(
          dialogContext,
          _ClientRenameDialogResult(customName: value.trim()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizationsStub.cancel(locale)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            const _ClientRenameDialogResult(resetToDefault: true),
          ),
          child: Text(AppLocalizationsStub.resetToDefault(locale)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            _ClientRenameDialogResult(customName: controller.text.trim()),
          ),
          child: Text(AppLocalizationsStub.save(locale)),
        ),
      ],
    ),
  );
  controller.dispose();

  if (result == null) {
    return null;
  }

  final updatedClient =
      result.resetToDefault || (result.customName?.trim().isEmpty ?? true)
      ? client.copyWith(clearDisplayName: true)
      : client.copyWith(displayName: result.customName!.trim());

  await ref.read(clientListProvider.notifier).renameClient(updatedClient);
  return updatedClient;
}

Future<void> _openExternalLink(BuildContext context, Uri uri) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.externalLinkErrorMessage ?? 'Could not open link'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

enum _SettingsWorkspaceSection { appearance, application, about }

class _ClientVisualSpec {
  final String eraLabel;
  final String? bannerAssetSlot;
  final String? iconAssetPath;
  final IconData emblemIcon;
  final List<Color> gradientColors;
  final Alignment begin;
  final Alignment end;
  final Color accentColor;
  final Color badgeColor;
  final Color badgeForeground;
  final Color overlayColor;

  const _ClientVisualSpec({
    required this.eraLabel,
    required this.bannerAssetSlot,
    required this.iconAssetPath,
    required this.emblemIcon,
    required this.gradientColors,
    required this.begin,
    required this.end,
    required this.accentColor,
    required this.badgeColor,
    required this.badgeForeground,
    required this.overlayColor,
  });
}

_ClientVisualSpec _buildClientVisualSpec(
  GameClient client,
  ColorScheme colorScheme,
) {
  final profile = WowVersionProfile.parse(client.version);

  Color soften(Color color, [double amount = 0.32]) =>
      Color.lerp(color, colorScheme.surface, amount) ?? color;

  return switch (profile.family) {
    WowVersionFamily.wrath => _ClientVisualSpec(
      eraLabel: 'Wrath of the Lich King',
      bannerAssetSlot: 'wrath',
      iconAssetPath: _clientIconAssetPath('wrath'),
      emblemIcon: Icons.ac_unit_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF143A6E), 0.16),
        soften(const Color(0xFF57A7E8), 0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFBFE3FF),
      badgeColor: const Color(0xFFE5F3FF),
      badgeForeground: const Color(0xFF143A6E),
      overlayColor: Colors.white,
    ),
    WowVersionFamily.cataclysm => _ClientVisualSpec(
      eraLabel: 'Cataclysm',
      bannerAssetSlot: 'cataclysm',
      iconAssetPath: _clientIconAssetPath('cataclysm'),
      emblemIcon: Icons.local_fire_department_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF3A1E14), 0.12),
        soften(const Color(0xFFD86E2B), 0.16),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFFFC18F),
      badgeColor: const Color(0xFFFFE4D0),
      badgeForeground: const Color(0xFF6A2E10),
      overlayColor: const Color(0xFFFFF4EC),
    ),
    WowVersionFamily.mistsOfPandaria => _ClientVisualSpec(
      eraLabel: 'Mists of Pandaria',
      bannerAssetSlot: 'mists_of_pandaria',
      iconAssetPath: _clientIconAssetPath('mists_of_pandaria'),
      emblemIcon: Icons.spa_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF0F524A), 0.12),
        soften(const Color(0xFF4DAF8F), 0.16),
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      accentColor: const Color(0xFFCFEFE5),
      badgeColor: const Color(0xFFE4F7EF),
      badgeForeground: const Color(0xFF104F43),
      overlayColor: Colors.white,
    ),
    WowVersionFamily.legion => _ClientVisualSpec(
      eraLabel: 'Legion',
      bannerAssetSlot: 'legion',
      iconAssetPath: _clientIconAssetPath('legion'),
      emblemIcon: Icons.shield_moon_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF13211A), 0.1),
        soften(const Color(0xFF5CBF58), 0.2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFD9FFD0),
      badgeColor: const Color(0xFFE9FFE5),
      badgeForeground: const Color(0xFF1F5F1A),
      overlayColor: const Color(0xFFF3FFF0),
    ),
    WowVersionFamily.battleForAzeroth => _ClientVisualSpec(
      eraLabel: 'Battle for Azeroth',
      bannerAssetSlot: 'battle_for_azeroth',
      iconAssetPath: _clientIconAssetPath('battle_for_azeroth'),
      emblemIcon: Icons.explore_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF1E2949), 0.08),
        soften(const Color(0xFFC99A36), 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFFFE4A8),
      badgeColor: const Color(0xFFFFF0CC),
      badgeForeground: const Color(0xFF624514),
      overlayColor: const Color(0xFFFFFAF0),
    ),
    WowVersionFamily.shadowlands => _ClientVisualSpec(
      eraLabel: 'Shadowlands',
      bannerAssetSlot: 'shadowlands',
      iconAssetPath: _clientIconAssetPath('shadowlands'),
      emblemIcon: Icons.dark_mode_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF221B36), 0.08),
        soften(const Color(0xFF8D79D6), 0.2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFE4DDFF),
      badgeColor: const Color(0xFFF1ECFF),
      badgeForeground: const Color(0xFF423170),
      overlayColor: const Color(0xFFF7F4FF),
    ),
    WowVersionFamily.dragonflight => _ClientVisualSpec(
      eraLabel: 'Dragonflight',
      bannerAssetSlot: 'dragonflight',
      iconAssetPath: _clientIconAssetPath('dragonflight'),
      emblemIcon: Icons.auto_awesome_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF622C24), 0.08),
        soften(const Color(0xFFE98646), 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFFFD9BE),
      badgeColor: const Color(0xFFFFEBDD),
      badgeForeground: const Color(0xFF6F3314),
      overlayColor: const Color(0xFFFFF5EE),
    ),
    WowVersionFamily.warWithin => _ClientVisualSpec(
      eraLabel: 'The War Within',
      bannerAssetSlot: 'the_war_within',
      iconAssetPath: _clientIconAssetPath('the_war_within'),
      emblemIcon: Icons.auto_awesome_motion_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF352520), 0.08),
        soften(const Color(0xFFC18B4A), 0.2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFFFDFB6),
      badgeColor: const Color(0xFFFFEDD4),
      badgeForeground: const Color(0xFF694119),
      overlayColor: const Color(0xFFFFF6EB),
    ),
    WowVersionFamily.vanilla => _ClientVisualSpec(
      eraLabel: client.type == ClientType.classic ? 'Classic Era' : 'Vanilla',
      bannerAssetSlot: 'classic_era',
      iconAssetPath: _clientIconAssetPath('classic_era'),
      emblemIcon: Icons.auto_awesome_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF4B3423), 0.12),
        soften(const Color(0xFF9A6D48), 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFF1D5BA),
      badgeColor: const Color(0xFFF7E8D8),
      badgeForeground: const Color(0xFF5E3B1F),
      overlayColor: const Color(0xFFFFF8F0),
    ),
    WowVersionFamily.burningCrusade => _ClientVisualSpec(
      eraLabel: client.type == ClientType.classic
          ? 'Burning Crusade Classic'
          : 'Burning Crusade',
      bannerAssetSlot: 'burning_crusade',
      iconAssetPath: _clientIconAssetPath('burning_crusade'),
      emblemIcon: Icons.shield_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF214253), 0.1),
        soften(const Color(0xFF6CC1C6), 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFCDEFF1),
      badgeColor: const Color(0xFFE6F8F9),
      badgeForeground: const Color(0xFF1F4D50),
      overlayColor: const Color(0xFFF4FEFF),
    ),
    WowVersionFamily.warlordsOfDraenor => _ClientVisualSpec(
      eraLabel: 'Warlords of Draenor',
      bannerAssetSlot: 'warlords_of_draenor',
      iconAssetPath: _clientIconAssetPath('warlords_of_draenor'),
      emblemIcon: Icons.gavel_rounded,
      gradientColors: <Color>[
        soften(const Color(0xFF4C241D), 0.08),
        soften(const Color(0xFFB3583D), 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: const Color(0xFFFFD0C1),
      badgeColor: const Color(0xFFFFE7E0),
      badgeForeground: const Color(0xFF6A2F23),
      overlayColor: const Color(0xFFFFF3EF),
    ),
    _ => _ClientVisualSpec(
      eraLabel: client.defaultDisplayName.split(' (').first,
      bannerAssetSlot: 'generic',
      iconAssetPath: _clientIconAssetPath('generic'),
      emblemIcon: Icons.extension_rounded,
      gradientColors: <Color>[
        colorScheme.primaryContainer,
        colorScheme.tertiaryContainer,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      accentColor: colorScheme.onPrimaryContainer,
      badgeColor: colorScheme.surface,
      badgeForeground: colorScheme.onSurface,
      overlayColor: colorScheme.onPrimaryContainer,
    ),
  };
}

String _clientBranchLabel(AppLocalizations l10n, ClientType type) {
  return switch (type) {
    ClientType.retail => l10n.dashboardClientTypeRetail,
    ClientType.classic => l10n.dashboardClientTypeClassic,
    ClientType.ptr => l10n.dashboardClientTypePtr,
    ClientType.legacy => l10n.dashboardClientTypeLegacy,
    ClientType.unknown => l10n.dashboardClientTypeUnknown,
  };
}

class _ClientVisualBanner extends StatelessWidget {
  final _ClientVisualSpec spec;
  final BorderRadius borderRadius;
  final _ClientBannerUsage bannerUsage;
  final bool compact;

  const _ClientVisualBanner({
    required this.spec,
    required this.borderRadius,
    required this.bannerUsage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: spec.gradientColors,
                begin: spec.begin,
                end: spec.end,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: compact ? 0.08 : 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: compact ? 0.08 : 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: compact ? -32 : -40,
            right: compact ? -24 : -30,
            child: Container(
              width: compact ? 112 : 144,
              height: compact ? 112 : 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spec.overlayColor.withValues(
                  alpha: compact ? 0.08 : 0.1,
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? -30 : -38,
            bottom: compact ? -56 : -68,
            child: Container(
              width: compact ? 128 : 160,
              height: compact ? 128 : 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: compact ? 0.04 : 0.06),
              ),
            ),
          ),
          if (spec.bannerAssetSlot != null)
            _OptionalClientBannerAsset(
              assetCandidates: _clientBannerAssetCandidates(
                spec.bannerAssetSlot!,
                bannerUsage,
              ),
              opacity: compact ? 0.2 : 0.28,
              alignment: compact
                  ? kClientBannerArtCompactAlignment
                  : kClientBannerArtAlignment,
              soften: compact,
            ),
          Positioned(
            right: compact ? 18 : 20,
            bottom: compact ? 10 : 14,
            child: _ClientEraGlyphAsset(
              spec: spec,
              size: compact ? 56 : 72,
              color: spec.overlayColor,
              opacity: compact ? 0.14 : 0.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalClientBannerAsset extends StatelessWidget {
  final List<String> assetCandidates;
  final double opacity;
  final Alignment alignment;
  final bool soften;

  const _OptionalClientBannerAsset({
    required this.assetCandidates,
    required this.opacity,
    required this.alignment,
    this.soften = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildImage(int index, double effectiveOpacity) {
      if (index >= assetCandidates.length) {
        return const SizedBox.shrink();
      }

      return Opacity(
        opacity: effectiveOpacity,
        child: Image.asset(
          assetCandidates[index],
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              buildImage(index + 1, effectiveOpacity),
        ),
      );
    }

    if (!soften) {
      return buildImage(0, opacity);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
            child: buildImage(0, opacity * 0.92),
          ),
        ),
        Positioned.fill(child: buildImage(0, opacity * 0.54)),
      ],
    );
  }
}
class _ClientEraMedallion extends StatelessWidget {
  final _ClientVisualSpec spec;
  final double size;

  const _ClientEraMedallion({required this.spec, this.size = 54});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: _ClientEraGlyphAsset(spec: spec, size: size),
      ),
    );
  }
}

class _ClientEraGlyphAsset extends StatelessWidget {
  final _ClientVisualSpec spec;
  final double size;
  final Color? color;
  final double opacity;

  const _ClientEraGlyphAsset({
    required this.spec,
    required this.size,
    this.color,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      spec.emblemIcon,
      size: size,
      color: color ?? spec.badgeForeground,
    );

    if (spec.iconAssetPath == null) {
      return Opacity(opacity: opacity, child: fallback);
    }

    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        spec.iconAssetPath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
        placeholderBuilder: (context) => fallback,
      ),
    );
  }
}

class _ClientPathLine extends StatelessWidget {
  final String path;

  const _ClientPathLine({required this.path});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: path,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBoostyPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _HomeBoostyPillButton({required this.label, required this.onPressed});

  @override
  State<_HomeBoostyPillButton> createState() => _HomeBoostyPillButtonState();
}

class _HomeBoostyPillButtonState extends State<_HomeBoostyPillButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      height: 1,
      color: colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.w700,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final textPainter = TextPainter(
      text: TextSpan(text: widget.label, style: labelStyle),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: 320);
    final expandedWidth = (40 + 8 + textPainter.width + 16)
        .clamp(40, 280)
        .toDouble();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 350),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onPressed,
            onHover: _setHovered,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _hovered ? expandedWidth : 40,
              height: 40,
              decoration: ShapeDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.9),
                shape: const StadiumBorder(),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        Icons.coffee_rounded,
                        size: 18,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        widthFactor: _hovered ? 1 : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2, right: 14),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAppBarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _HomeAppBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  final GameClient client;
  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final spec = _buildClientVisualSpec(client, colorScheme);
    final displayName = client.resolvedDisplayName;
    final eraLabel = client.defaultDisplayName.split(' (').first;
    void onOpen() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClientDetailsScreen(client: client),
        ),
      );
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ClientVisualBanner(
                    spec: spec,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    bannerUsage: _ClientBannerUsage.compactCard,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ClientHeroBadge(
                                    label: _clientBranchLabel(
                                      l10n,
                                      client.type,
                                    ),
                                    backgroundColor: Colors.black.withValues(
                                      alpha: 0.18,
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  _ClientHeroBadge(
                                    label: client.version,
                                    backgroundColor: spec.badgeColor.withValues(
                                      alpha: 0.96,
                                    ),
                                    foregroundColor: spec.badgeForeground,
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: l10n.dashboardRenameClient,
                              onPressed: () => _promptRenameClient(
                                context,
                                ref,
                                client,
                                Localizations.localeOf(context).languageCode,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.18,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          eraLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ClientEraMedallion(spec: spec, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.dashboardClientLocation,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ClientPathLine(path: client.path),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.extension_rounded),
                      style: FilledButton.styleFrom(
                        backgroundColor: spec.badgeColor,
                        foregroundColor: spec.badgeForeground,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: Text(l10n.dashboardManageAddons),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientHeroBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ClientHeroBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class ClientDetailsScreen extends ConsumerStatefulWidget {
  final GameClient client;
  const ClientDetailsScreen({super.key, required this.client});

  @override
  ConsumerState<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  final GlobalKey<_LocalAddonsViewState> _localAddonsKey =
      GlobalKey<_LocalAddonsViewState>();
  final ScrollController _nestedScrollController = ScrollController();
  late GameClient _client;
  int _currentIndex = 0;
  int _selectedLocalAddons = 0;
  bool _isLaunchingGame = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  @override
  void dispose() {
    _nestedScrollController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) {
      return;
    }

    if (_currentIndex == 0) {
      _localAddonsKey.currentState?.clearSelection();
    }

    setState(() => _currentIndex = index);
  }

  bool get _canLaunchGame {
    final executableName = _client.executableName?.trim() ?? '';
    return executableName.isNotEmpty;
  }

  Future<void> _handleLaunchGame() async {
    if (_isLaunchingGame) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLaunchingGame = true);

    try {
      await ref.read(launchGameUseCaseProvider)(_client);
    } on LaunchGameException catch (error) {
      if (!mounted) {
        return;
      }

      final message = switch (error.failure) {
        LaunchGameFailure.missingExecutableName =>
          l10n.clientLaunchMissingExecutable,
        LaunchGameFailure.executableNotFound =>
          l10n.clientLaunchMissingExecutable,
        LaunchGameFailure.invalidClientPath => l10n.clientLaunchInvalidPath,
        LaunchGameFailure.launchFailed => l10n.clientLaunchFailed,
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.clientLaunchFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunchingGame = false);
      }
    }
  }

  Widget _buildCurrentTab() {
    if (_currentIndex == 0) {
      return _LocalAddonsView(
        key: _localAddonsKey,
        client: _client,
        onSelectionChanged: (count) {
          if (_selectedLocalAddons != count) {
            setState(() => _selectedLocalAddons = count);
          }
        },
      );
    }

    return KeyedSubtree(
      key: ValueKey<String>('client-search-${_client.id}'),
      child: _SearchAddonsView(client: _client),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final l10n = AppLocalizations.of(context)!;
    final isSelectionMode = _currentIndex == 0 && _selectedLocalAddons > 0;
    final useDesktopImprovedScrolling = _shouldUseDesktopImprovedScrolling();
    final scrollView = CustomScrollView(
      controller: _nestedScrollController,
      physics: useDesktopImprovedScrolling
          ? const NeverScrollableScrollPhysics()
          : null,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ClientHeroHeaderDelegate(
            client: _client,
            launchLabel: l10n.clientLaunchAction,
            onLaunch: _canLaunchGame ? _handleLaunchGame : null,
            isLaunching: _isLaunchingGame,
          ),
        ),
        _buildCurrentTab(),
      ],
    );
    final scrollableBody = _currentIndex == 0
        ? RefreshIndicator(
            onRefresh: () =>
                ref.read(localAddonsProvider(_client).notifier).refresh(),
            child: scrollView,
          )
        : scrollView;

    return PerformanceTrackedScope(
      screenName: 'ClientDetails',
      child: Scaffold(
        appBar: AppBar(
          title: isSelectionMode
              ? Text(
                  AppLocalizationsStub.selectedCount(
                    locale,
                    _selectedLocalAddons,
                  ),
                )
              : null,
          actions: [
            if (isSelectionMode) ...[
              IconButton(
                tooltip: AppLocalizationsStub.deleteSelected(locale),
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () =>
                    _localAddonsKey.currentState?.deleteSelectedFromAppBar(),
              ),
              IconButton(
                tooltip: AppLocalizationsStub.clearSelection(locale),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _localAddonsKey.currentState?.clearSelection(),
              ),
            ] else
              IconButton(
                tooltip: AppLocalizationsStub.renameClient(locale),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final updatedClient = await _promptRenameClient(
                    context,
                    ref,
                    _client,
                    locale,
                  );
                  if (updatedClient != null && mounted) {
                    setState(() => _client = updatedClient);
                  }
                },
              ),
            if (!isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  await ref
                      .read(clientListProvider.notifier)
                      .removeClient(_client.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            if (useDesktopImprovedScrolling)
              _DesktopImprovedScrolling(
                controller: _nestedScrollController,
                child: scrollableBody,
              )
            else
              scrollableBody,
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: _ClientDetailsNavBar(
                  client: _client,
                  currentIndex: _currentIndex,
                  onTap: _onNavTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDetailsNavBar extends StatelessWidget {
  final GameClient client;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ClientDetailsNavBar({
    required this.client,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spec = _buildClientVisualSpec(client, colorScheme);
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(44),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailsNavItem(
              icon: Icons.inventory_2_rounded,
              isSelected: currentIndex == 0,
              selectedBackgroundColor: spec.badgeColor,
              selectedForegroundColor: spec.badgeForeground,
              onTap: () => onTap(0),
            ),
            _DetailsNavItem(
              icon: Icons.search_rounded,
              isSelected: currentIndex == 1,
              selectedBackgroundColor: spec.badgeColor,
              selectedForegroundColor: spec.badgeForeground,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsNavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color selectedBackgroundColor;
  final Color selectedForegroundColor;
  final VoidCallback onTap;

  const _DetailsNavItem({
    required this.icon,
    required this.isSelected,
    required this.selectedBackgroundColor,
    required this.selectedForegroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: isSelected ? 64 : 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? selectedBackgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected
                    ? selectedForegroundColor
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalAddonsView extends ConsumerStatefulWidget {
  final GameClient client;
  final ValueChanged<int>? onSelectionChanged;

  const _LocalAddonsView({
    super.key,
    required this.client,
    this.onSelectionChanged,
  });

  @override
  ConsumerState<_LocalAddonsView> createState() => _LocalAddonsViewState();
}

class _LocalAddonsViewState extends ConsumerState<_LocalAddonsView> {
  final Set<String> _selectedIds = <String>{};

  void clearSelection() {
    if (_selectedIds.isEmpty) {
      return;
    }

    setState(() {
      _selectedIds.clear();
    });
    widget.onSelectionChanged?.call(0);
  }

  void _toggleSelectAll(List<InstalledAddonGroup> groups) {
    if (groups.isEmpty) {
      clearSelection();
      return;
    }

    final visibleIds = groups.map((group) => group.id).toSet();
    final shouldClear =
        visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds);

    setState(() {
      _selectedIds
        ..clear()
        ..addAll(shouldClear ? const <String>{} : visibleIds);
    });
    widget.onSelectionChanged?.call(_selectedIds.length);
  }

  Future<void> _handleManualImport(String locale) async {
    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      dialogTitle: AppLocalizationsStub.installFromArchive(locale),
    );
    final archivePath = pickedFile?.files.single.path;
    if (archivePath == null || archivePath.trim().isEmpty) {
      return;
    }

    await _runManualImport(archivePath, locale: locale);
  }

  Future<void> _runManualImport(
    String sourcePath, {
    required String locale,
    bool replaceExisting = false,
  }) async {
    final notifier = ref.read(localAddonsProvider(widget.client).notifier);

    try {
      await notifier.importAddonFromArchive(
        sourcePath,
        replaceExisting: replaceExisting,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizationsStub.installSuccess(locale)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on AddonInstallConflictException catch (error) {
      if (!mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizationsStub.replaceFoldersTitle(locale)),
          content: Text(
            AppLocalizationsStub.replaceFoldersMessage(
              locale,
              error.folderNames.join(', '),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizationsStub.cancel(locale)),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizationsStub.replace(locale)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _runManualImport(
          sourcePath,
          locale: locale,
          replaceExisting: true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizationsStub.installError(locale)}: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> deleteSelectedFromAppBar() async {
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    final groups =
        ref.read(localAddonsProvider(widget.client)).valueOrNull ??
        const <InstalledAddonGroup>[];
    final selectedGroups = groups
        .where((group) => _selectedIds.contains(group.id))
        .toList();
    if (selectedGroups.isEmpty) {
      clearSelection();
      return;
    }

    await _handleDeleteGroups(selectedGroups, locale);
  }

  Future<void> _handleDeleteGroups(
    List<InstalledAddonGroup> groups,
    String locale,
  ) async {
    final theme = Theme.of(context);
    final displayName = groups.length == 1
        ? groups.first.displayName
        : AppLocalizationsStub.selectedCount(locale, groups.length);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizationsStub.confirmDeleteTitle(locale)),
        content: Text(
          AppLocalizationsStub.confirmDeleteMessage(locale, displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizationsStub.cancel(locale)),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              groups.length == 1
                  ? AppLocalizationsStub.delete(locale)
                  : AppLocalizationsStub.deleteSelected(locale),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      if (groups.length == 1) {
        await ref
            .read(localAddonsProvider(widget.client).notifier)
            .deleteAddon(groups.first);
      } else {
        await ref
            .read(localAddonsProvider(widget.client).notifier)
            .deleteAddons(groups);
      }

      clearSelection();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizationsStub.installError(locale)}: $error'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _toggleSelection(String groupId) {
    setState(() {
      if (_selectedIds.contains(groupId)) {
        _selectedIds.remove(groupId);
      } else {
        _selectedIds.add(groupId);
      }
    });
    widget.onSelectionChanged?.call(_selectedIds.length);
  }

  void _syncSelection(List<InstalledAddonGroup> groups) {
    final validIds = groups.map((group) => group.id).toSet();
    final selectedIds = _selectedIds.where(validIds.contains).toSet();
    if (selectedIds.length == _selectedIds.length) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(selectedIds);
      });
      widget.onSelectionChanged?.call(_selectedIds.length);
    });
  }

  Widget _buildActionBar(
    BuildContext context,
    String locale,
    List<InstalledAddonGroup> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelectionMode = _selectedIds.isNotEmpty;
    final allVisibleSelected =
        groups.isNotEmpty &&
        _selectedIds.length == groups.length &&
        groups.every((group) => _selectedIds.contains(group.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelectionMode
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                (isSelectionMode
                        ? colorScheme.primary
                        : colorScheme.outlineVariant)
                    .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelectionMode
                  ? Icons.checklist_rounded
                  : Icons.inventory_2_rounded,
              color: isSelectionMode
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelectionMode
                        ? AppLocalizationsStub.selectedCount(
                            locale,
                            _selectedIds.length,
                          )
                        : AppLocalizationsStub.myAddons(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelectionMode
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isSelectionMode
                        ? AppLocalizationsStub.deleteSelected(locale)
                        : AppLocalizationsStub.refreshAddons(locale),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelectionMode
                          ? colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.8,
                            )
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: AppLocalizationsStub.refreshAddons(locale),
              onPressed: () => ref
                  .read(localAddonsProvider(widget.client).notifier)
                  .refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: AppLocalizationsStub.installFromArchive(locale),
              onPressed: () => _handleManualImport(locale),
              icon: const Icon(Icons.file_download_done_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: allVisibleSelected
                  ? AppLocalizationsStub.clearAll(locale)
                  : AppLocalizationsStub.selectAll(locale),
              onPressed: groups.isEmpty ? null : () => _toggleSelectAll(groups),
              icon: Icon(
                allVisibleSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
            ),
            if (isSelectionMode) ...[
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: AppLocalizationsStub.deleteSelected(locale),
                onPressed: deleteSelectedFromAppBar,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final addonsAsync = ref.watch(localAddonsProvider(widget.client));
    final currentAddons =
        addonsAsync.valueOrNull ?? const <InstalledAddonGroup>[];

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: _buildActionBar(context, locale, currentAddons),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ...addonsAsync.when(
          data: (addons) {
            _syncSelection(addons);

            if (addons.isEmpty) {
              return <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizationsStub.noLocalAddons(locale),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            }

            return <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final addon = addons[index];
                    final isSelected = _selectedIds.contains(addon.id);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == addons.length - 1 ? 0 : 12,
                      ),
                      child: RepaintBoundary(
                        child: _InstalledAddonCard(
                          addon: addon,
                          isSelected: isSelected,
                          locale: locale,
                          onToggleSelection: () => _toggleSelection(addon.id),
                          onDelete: () => _handleDeleteGroups([addon], locale),
                        ),
                      ),
                    );
                  }, childCount: addons.length),
                ),
              ),
            ];
          },
          loading: () => <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingState(label: l10n.clientDetailsLoadingAddons),
            ),
          ],
          error: (e, s) => <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _StatusMessage(
                icon: Icons.error_outline_rounded,
                title: l10n.clientDetailsLoadErrorTitle,
                message: l10n.clientDetailsLoadErrorMessage(_formatError(e)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InstalledAddonCard extends StatelessWidget {
  final InstalledAddonGroup addon;
  final bool isSelected;
  final String locale;
  final VoidCallback onToggleSelection;
  final VoidCallback onDelete;

  const _InstalledAddonCard({
    required this.addon,
    required this.isSelected,
    required this.locale,
    required this.onToggleSelection,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color:
              (isSelected ? colorScheme.secondary : colorScheme.outlineVariant)
                  .withValues(alpha: 0.35),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('installed-addon-expansion-${addon.id}'),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          leading: Checkbox(
            value: isSelected,
            onChanged: (_) => onToggleSelection(),
          ),
          title: GestureDetector(
            onLongPress: onToggleSelection,
            child: Row(
              children: [
                _InstalledAddonGroupThumbnail(group: addon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.folder_copy_outlined,
                            label: AppLocalizationsStub.addonFolders(
                              locale,
                              addon.installedFolders.length,
                            ),
                          ),
                          _InfoChip(
                            icon: addon.isManaged
                                ? Icons.link_rounded
                                : Icons.home_repair_service_rounded,
                            label: addon.providerName == 'Manual'
                                ? AppLocalizationsStub.localManual(locale)
                                : addon.providerName ??
                                      AppLocalizationsStub.localManual(locale),
                          ),
                          if ((addon.version ?? '').isNotEmpty)
                            _InfoChip(
                              icon: Icons.sell_outlined,
                              label: addon.version!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final folderName in addon.installedFolders)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folderName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(AppLocalizationsStub.delete(locale)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatError(Object error) {
  final message = error.toString().trim();
  return message.startsWith('Exception: ')
      ? message.substring('Exception: '.length)
      : message;
}

class _LoadingState extends StatelessWidget {
  final String label;

  const _LoadingState({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedIntroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeedIntroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAddonsView extends ConsumerStatefulWidget {
  final GameClient client;

  const _SearchAddonsView({required this.client});

  @override
  ConsumerState<_SearchAddonsView> createState() => _SearchAddonsViewState();
}

class _SearchAddonsViewState extends ConsumerState<_SearchAddonsView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  ClientSearchScopeKey get _scopeKey => ClientSearchScopeKey(
    clientId: widget.client.id,
    gameVersion: widget.client.version,
  );

  String get _normalizedQuery => _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    ref.invalidate(searchResultsProvider(_scopeKey));
  }

  void _handleQueryChanged(String value) {
    final normalizedValue = value.trim();
    if (_query != normalizedValue) {
      setState(() => _query = normalizedValue);
    }

    if (normalizedValue.isEmpty) {
      ref.invalidate(searchResultsProvider(_scopeKey));
      return;
    }

    ref
        .read(searchResultsProvider(_scopeKey).notifier)
        .search(normalizedValue, gameVersion: widget.client.version);
  }

  Widget _buildDiscoveryFeed() {
    return _SearchFeedSliverContent(
      client: widget.client,
      scopeKey: _scopeKey,
      query: '',
      isDiscoveryMode: true,
    );
  }

  Widget _buildSearchResults() {
    return _SearchFeedSliverContent(
      client: widget.client,
      scopeKey: _scopeKey,
      query: _normalizedQuery,
      isDiscoveryMode: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDiscoveryMode = _normalizedQuery.isEmpty;
    final sectionTitle = isDiscoveryMode
        ? l10n.discoveryFeedTitle(widget.client.version)
        : l10n.searchResultsTitle(_normalizedQuery);
    final sectionSubtitle = isDiscoveryMode
        ? l10n.discoveryFeedSubtitle(widget.client.version)
        : l10n.searchResultsSubtitle(widget.client.version);

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchBar(
              controller: _searchController,
              hintText: l10n.searchAddonsHint,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_normalizedQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: _clearSearch,
                  ),
              ],
              onChanged: _handleQueryChanged,
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(
                colorScheme.surfaceContainer,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _FeedIntroCard(
              icon: isDiscoveryMode
                  ? Icons.auto_awesome_rounded
                  : Icons.search_rounded,
              title: sectionTitle,
              subtitle: sectionSubtitle,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (isDiscoveryMode) _buildDiscoveryFeed() else _buildSearchResults(),
      ],
    );
  }
}

class _ClientHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  final GameClient client;
  final String launchLabel;
  final VoidCallback? onLaunch;
  final bool isLaunching;

  const _ClientHeroHeaderDelegate({
    required this.client,
    required this.launchLabel,
    required this.onLaunch,
    required this.isLaunching,
  });

  @override
  double get minExtent => 100;

  @override
  double get maxExtent => 232;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final spec = _buildClientVisualSpec(client, colorScheme);
    final branchLabel = _clientBranchLabel(l10n, client.type);
    final collapseRange = maxExtent - minExtent;
    final collapseT = collapseRange <= 0
        ? 1.0
        : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final visualT = Curves.easeInOutCubicEmphasized.transform(collapseT);
    final surfaceRadius = 30 - (8 * visualT);
    final medallionSize = 56 - (12 * visualT);
    final expandedMetaOpacity = (1 - (visualT * 1.2)).clamp(0.0, 1.0);
    final topBadgeOpacity = (1 - (visualT * 1.45)).clamp(0.0, 1.0);
    final compactMode = visualT > 0.7;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(surfaceRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ClientVisualBanner(
                spec: spec,
                borderRadius: BorderRadius.circular(surfaceRadius),
                bannerUsage: _ClientBannerUsage.mediumHero,
                compact: collapseT > 0.42,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20 - (4 * visualT),
                  16 - (2 * visualT),
                  20 - (4 * visualT),
                  16 - (4 * visualT),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30 * topBadgeOpacity,
                      child: Opacity(
                        opacity: topBadgeOpacity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ClientHeroBadge(
                              label: branchLabel,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            _ClientHeroBadge(
                              label: client.version,
                              backgroundColor: spec.badgeColor.withValues(
                                alpha: 0.96,
                              ),
                              foregroundColor: spec.badgeForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10 * (1 - visualT)),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 1 - (0.08 * visualT),
                          alignment: Alignment.centerLeft,
                          child: _ClientEraMedallion(
                            spec: spec,
                            size: medallionSize.clamp(40.0, 56.0),
                          ),
                        ),
                        SizedBox(width: 14 - (4 * visualT)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                client.resolvedDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                              ),
                              SizedBox(height: 6 * expandedMetaOpacity),
                              Opacity(
                                opacity: expandedMetaOpacity,
                                child: Text(
                                  '$branchLabel · ${client.version}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ClientHeroLaunchButton(
                          label: launchLabel,
                          isCompact: compactMode,
                          isLaunching: isLaunching,
                          onPressed: onLaunch,
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * expandedMetaOpacity),
                    ClipRect(
                      child: Align(
                        heightFactor: expandedMetaOpacity,
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: expandedMetaOpacity,
                          child: _ClientHeaderPathPill(path: client.path),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ClientHeroHeaderDelegate oldDelegate) {
    return oldDelegate.client != client ||
        oldDelegate.launchLabel != launchLabel ||
        oldDelegate.onLaunch != onLaunch ||
        oldDelegate.isLaunching != isLaunching;
  }
}

class _ClientHeroLaunchButton extends StatelessWidget {
  final String label;
  final bool isCompact;
  final bool isLaunching;
  final VoidCallback? onPressed;

  const _ClientHeroLaunchButton({
    required this.label,
    required this.isCompact,
    required this.isLaunching,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isLaunching
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.play_arrow_rounded);

    if (isCompact) {
      return IconButton.filledTonal(
        tooltip: label,
        onPressed: isLaunching ? null : onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: isLaunching ? null : onPressed,
      icon: icon,
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _ClientHeaderPathPill extends StatelessWidget {
  final String path;

  const _ClientHeaderPathPill({required this.path});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 15,
              color: Colors.white.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFeedSliverContent extends ConsumerWidget {
  final GameClient client;
  final ClientSearchScopeKey scopeKey;
  final String query;
  final bool isDiscoveryMode;

  const _SearchFeedSliverContent({
    required this.client,
    required this.scopeKey,
    required this.query,
    required this.isDiscoveryMode,
  });

  ProviderListenable<AddonFeedState> get _feedProvider => isDiscoveryMode
      ? discoveryFeedProvider(scopeKey)
      : searchResultsProvider(scopeKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(
      appSettingsProvider.select((state) => state.locale.languageCode),
    );
    final shellState = ref.watch(
      _feedProvider.select(
        (state) => (
          hasResults: state.hasResults,
          hasError: state.hasError && !state.hasResults,
          isInitialLoading: state.isLoading && !state.hasResults,
          canLoadMore: state.canLoadMore,
          error: state.hasError ? state.error : null,
        ),
      ),
    );

    if (shellState.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StatusMessage(
          icon: isDiscoveryMode
              ? Icons.cloud_off_rounded
              : Icons.error_outline_rounded,
          title: isDiscoveryMode
              ? l10n.discoveryFeedErrorTitle
              : l10n.searchErrorTitle,
          message: isDiscoveryMode
              ? l10n.discoveryFeedErrorMessage(
                  client.version,
                  _formatError(shellState.error!),
                )
              : l10n.searchErrorMessage(_formatError(shellState.error!)),
          actionLabel: l10n.retryButton,
          onAction: isDiscoveryMode
              ? () => ref.read(discoveryFeedProvider(scopeKey).notifier).load()
              : () => ref
                    .read(searchResultsProvider(scopeKey).notifier)
                    .search(query, gameVersion: client.version),
        ),
      );
    }

    if (shellState.isInitialLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _LoadingState(
          label: isDiscoveryMode
              ? l10n.discoveryFeedLoading(client.version)
              : l10n.searchLoading(query),
        ),
      );
    }

    if (!shellState.hasResults) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StatusMessage(
          icon: isDiscoveryMode
              ? Icons.travel_explore_rounded
              : Icons.search_off_rounded,
          title: isDiscoveryMode
              ? l10n.discoveryFeedEmptyTitle
              : l10n.searchNoResultsTitle,
          message: isDiscoveryMode
              ? l10n.discoveryFeedEmptyMessage(client.version)
              : l10n.searchNoResultsMessage(query, client.version),
          actionLabel: isDiscoveryMode && shellState.canLoadMore
              ? AppLocalizationsStub.loadMore(locale)
              : null,
          onAction: isDiscoveryMode && shellState.canLoadMore
              ? () => ref
                    .read(discoveryFeedProvider(scopeKey).notifier)
                    .loadMore()
              : null,
        ),
      );
    }

    return _VerifiedFeedSliverSection(
      feedProvider: _feedProvider,
      client: client,
      showLoadMore: isDiscoveryMode,
      onLoadMore: isDiscoveryMode
          ? () => ref.read(discoveryFeedProvider(scopeKey).notifier).loadMore()
          : null,
    );
  }
}

class _VerifiedFeedSliverSection extends ConsumerWidget {
  final ProviderListenable<AddonFeedState> feedProvider;
  final GameClient client;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;

  const _VerifiedFeedSliverSection({
    required this.feedProvider,
    required this.client,
    this.showLoadMore = false,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsSnapshot = ref.watch(
      feedProvider.select(_FeedItemsSnapshot.fromState),
    );
    final locale = ref.watch(
      appSettingsProvider.select((state) => state.locale.languageCode),
    );
    final items = itemsSnapshot.items;
    final installedGroups = ref.watch(
      localAddonsProvider(
        client,
      ).select((state) => state.valueOrNull ?? const <InstalledAddonGroup>[]),
    );
    final addonService = ref.read(addonServiceProvider);

    final installedMatches = List<AddonInstalledMatch>.generate(
      items.length,
      (index) =>
          addonService.matchInstalledAddon(items[index], installedGroups),
      growable: false,
    );

    final children = <Widget>[
      for (var index = 0; index < items.length; index++) ...[
        RepaintBoundary(
          child: _AnimatedFeedEntry(
            key: ValueKey(
              '${items[index].providerName}:${items[index].originalId}',
            ),
            child: AddonSearchResultTile(
              mod: items[index],
              client: client,
              localeCode: locale,
              installedMatch: installedMatches[index],
            ),
          ),
        ),
        if (index < items.length - 1) const SizedBox(height: 12),
      ],
    ];

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.list(children: children),
        ),
        if (showLoadMore && onLoadMore != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _DiscoveryLoadMoreBar(
                feedProvider: feedProvider,
                onPressed: onLoadMore!,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _DiscoveryLoadMoreBar extends ConsumerWidget {
  final ProviderListenable<AddonFeedState> feedProvider;
  final VoidCallback onPressed;

  const _DiscoveryLoadMoreBar({
    required this.feedProvider,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appSettingsProvider.select((state) => state.locale.languageCode),
    );
    final viewState = ref.watch(
      feedProvider.select(
        (state) => (
          hasResults: state.hasResults,
          canLoadMore: state.canLoadMore,
          isLoading: state.isLoading,
        ),
      ),
    );

    if (!viewState.hasResults ||
        (!viewState.canLoadMore && !viewState.isLoading)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: viewState.isLoading ? null : onPressed,
          icon: viewState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(AppLocalizationsStub.loadMore(locale)),
        ),
      ),
    );
  }
}

class _AnimatedFeedEntry extends StatefulWidget {
  final Widget child;

  const _AnimatedFeedEntry({super.key, required this.child});

  @override
  State<_AnimatedFeedEntry> createState() => _AnimatedFeedEntryState();
}

class _AnimatedFeedEntryState extends State<_AnimatedFeedEntry> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _isVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _isVisible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _FeedItemsSnapshot {
  final String signature;
  final List<AddonItem> items;

  const _FeedItemsSnapshot({required this.signature, required this.items});

  factory _FeedItemsSnapshot.fromState(AddonFeedState state) {
    return _FeedItemsSnapshot(
      signature: state.items
          .map((item) => '${item.providerName}:${item.originalId}')
          .join('|'),
      items: state.items,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _FeedItemsSnapshot && other.signature == signature;
  }

  @override
  int get hashCode => signature.hashCode;
}

class AddonSearchResultTile extends ConsumerStatefulWidget {
  final AddonItem mod;
  final GameClient client;
  final String localeCode;
  final AddonInstalledMatch installedMatch;
  final ValueChanged<List<String>>? onInstalled;
  const AddonSearchResultTile({
    super.key,
    required this.mod,
    required this.client,
    required this.localeCode,
    required this.installedMatch,
    this.onInstalled,
  });

  @override
  ConsumerState<AddonSearchResultTile> createState() =>
      _AddonSearchResultTileState();
}

class _AddonSearchResultTileState extends ConsumerState<AddonSearchResultTile> {
  bool _isInstalling = false;

  Future<bool> _handleInstall() async {
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    setState(() => _isInstalling = true);

    try {
      final installAddon = ref.read(installAddonUseCaseProvider);
      final localAddonsNotifier = ref.read(
        localAddonsProvider(widget.client).notifier,
      );

      if (!mounted) return false;

      final result = await installAddon(
        addon: widget.mod,
        client: widget.client,
      );

      if (!mounted) return false;

      if (result.status == InstallAddonStatus.versionNotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizationsStub.versionNotFound(
                locale,
                widget.client.version,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      } else if (result.status == InstallAddonStatus.alreadyInstalled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizationsStub.alreadyInstalled(locale, widget.mod.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        return false;
      } else if (result.status == InstallAddonStatus.success) {
        await localAddonsNotifier.refresh();
        if (!mounted) return false;
        widget.onInstalled?.call(result.installedFolders);
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizationsStub.installSuccess(locale)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        return true;
      } else if (result.error != null) {
        throw result.error!;
      }
    } catch (e) {
      if (mounted) {
        final errorText = '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorText.contains('ALREADY_INSTALLED')
                  ? AppLocalizationsStub.alreadyInstalled(
                      locale,
                      widget.mod.name,
                    )
                  : '${AppLocalizationsStub.installError(locale)}: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }

    return false;
  }

  ButtonStyle _addonActionButtonStyle(
    BuildContext context, {
    required bool installed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    if (!installed) {
      return baseStyle;
    }

    return baseStyle.copyWith(
      backgroundColor: WidgetStateProperty.all(colorScheme.secondaryContainer),
      foregroundColor: WidgetStateProperty.all(
        colorScheme.onSecondaryContainer,
      ),
      side: WidgetStateProperty.all(
        BorderSide(color: colorScheme.secondary.withValues(alpha: 0.28)),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  Widget _buildAddonActionControl(
    BuildContext context,
    String locale, {
    required bool isInstalled,
    required bool isBusy,
    VoidCallback? onInstallPressed,
  }) {
    if (isInstalled) {
      return FilledButton.tonalIcon(
        onPressed: () {},
        style: _addonActionButtonStyle(context, installed: true),
        icon: const Icon(Icons.check_circle_rounded, size: 16),
        label: Text(
          AppLocalizationsStub.installed(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return FilledButton.tonal(
      onPressed: isBusy ? () {} : onInstallPressed,
      style: _addonActionButtonStyle(context, installed: false),
      child: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(AppLocalizationsStub.install(locale)),
    );
  }

  Future<void> _showDetailsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final authorName = widget.mod.author?.trim();
    final summary = widget.mod.summary.trim().isEmpty
        ? l10n.addonNoDescription
        : widget.mod.summary;
    final screenshotUrls = widget.mod.screenshotUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final maxWidth = size.width > 920 ? 760.0 : size.width * 0.92;
        final maxHeight = size.height > 760 ? 620.0 : size.height * 0.86;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AddonThumbnail(
                        url: widget.mod.thumbnailUrl,
                        size: 92,
                        borderRadius: 20,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.mod.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ProviderBadge(
                                  providerName: widget.mod.providerName,
                                ),
                                _AddonMetadataChip(
                                  icon: Icons.sell_outlined,
                                  label: l10n.addonVersionLabel(
                                    widget.mod.version,
                                  ),
                                ),
                                if (authorName != null && authorName.isNotEmpty)
                                  _AddonMetadataChip(
                                    icon: Icons.person_outline_rounded,
                                    label: l10n.addonAuthorLabel(
                                      '${widget.mod.providerName == GitHubProvider.staticProviderName ? '@' : ''}$authorName',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: l10n.addonDetailsClose,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (screenshotUrls.isNotEmpty) ...[
                    Text(
                      l10n.addonDetailsGalleryTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 108,
                      child: _AddonScreenshotGallery(urls: screenshotUrls),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    l10n.addonDetailsDescriptionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        summary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.addonDetailsClose),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 132),
                        child: widget.installedMatch.isInstalled
                            ? _buildInstalledBadge(
                                context,
                                widget.localeCode,
                              )
                            : _buildAddonActionControl(
                                context,
                                widget.localeCode,
                                isInstalled: false,
                                isBusy: _isInstalling,
                                onInstallPressed: () async {
                                  final didInstall = await _handleInstall();
                                  if (didInstall && dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstalledBadge(BuildContext context, String locale) {
    return _buildAddonActionControl(
      context,
      locale,
      isInstalled: true,
      isBusy: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.localeCode;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final installedMatch = widget.installedMatch;
    final authorName = widget.mod.author?.trim();
    final authorLabel = authorName == null || authorName.isEmpty
        ? null
        : l10n.addonAuthorLabel(
            '${widget.mod.providerName == GitHubProvider.staticProviderName ? '@' : ''}$authorName',
          );
    final summary = widget.mod.summary.trim().isEmpty
        ? l10n.addonNoDescription
        : widget.mod.summary;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _showDetailsDialog,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddonThumbnail(url: widget.mod.thumbnailUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mod.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (authorLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        authorLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 126,
                  maxWidth: 146,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ProviderBadge(
                        providerName: widget.mod.providerName,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.addonVersionLabel(widget.mod.version),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: installedMatch.isInstalled
                          ? _buildInstalledBadge(context, locale)
                          : _buildAddonActionControl(
                              context,
                              locale,
                              isInstalled: false,
                              isBusy: _isInstalling,
                              onInstallPressed: () {
                                _handleInstall();
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonMetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AddonMetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonScreenshotGallery extends StatelessWidget {
  final List<String> urls;

  const _AddonScreenshotGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: urls.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final url = urls[index];
        return AspectRatio(
          aspectRatio: 1.72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddonThumbnail extends StatelessWidget {
  final String? url;
  final double size;
  final double borderRadius;

  const _AddonThumbnail({
    required this.url,
    this.size = 64,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedUrl = url?.trim() ?? '';

    if (normalizedUrl.isEmpty) {
      return _AddonThumbnailPlaceholder(
        colorScheme: colorScheme,
        size: size,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        normalizedUrl,
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) =>
            _AddonThumbnailPlaceholder(
              colorScheme: colorScheme,
              size: size,
              borderRadius: borderRadius,
            ),
      ),
    );
  }
}

class _AddonThumbnailPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;
  final double size;
  final double borderRadius;

  const _AddonThumbnailPlaceholder({
    required this.colorScheme,
    this.size = 64,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.extension_rounded,
        color: colorScheme.onSurfaceVariant,
        size: size * 0.42,
      ),
    );
  }
}

class _InstalledAddonGroupThumbnail extends StatelessWidget {
  final InstalledAddonGroup group;

  const _InstalledAddonGroupThumbnail({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isManaged = group.isManaged;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _AddonThumbnail(url: group.thumbnailUrl, size: 52, borderRadius: 16),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isManaged
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              border: Border.all(color: colorScheme.surface, width: 2),
            ),
            child: Icon(
              isManaged ? Icons.cloud_done_rounded : Icons.folder_rounded,
              size: 13,
              color: isManaged
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final String providerName;
  const _ProviderBadge({required this.providerName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCF = providerName == 'CurseForge';

    Color bgColor = colorScheme.surfaceContainerHighest;
    Color textColor = colorScheme.onSurfaceVariant;
    Color borderColor = colorScheme.outlineVariant.withValues(alpha: 0.42);

    if (isCF) {
      bgColor = colorScheme.tertiaryContainer.withValues(alpha: 0.86);
      textColor = colorScheme.onTertiaryContainer;
      borderColor = colorScheme.tertiary.withValues(alpha: 0.28);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        providerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsWorkspaceSection _currentSection =
      _SettingsWorkspaceSection.appearance;

  void _selectSection(_SettingsWorkspaceSection section) {
    if (_currentSection == section) {
      return;
    }

    setState(() => _currentSection = section);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = <_SettingsWorkspaceSectionMeta>[
      _SettingsWorkspaceSectionMeta(
        section: _SettingsWorkspaceSection.appearance,
        icon: AppIcons.appearance,
        title: l10n.settingsAppearanceTitle,
        subtitle: l10n.settingsAppearanceSubtitle,
      ),
      _SettingsWorkspaceSectionMeta(
        section: _SettingsWorkspaceSection.application,
        icon: AppIcons.application,
        title: l10n.settingsApplicationTitle,
        subtitle: l10n.settingsApplicationSubtitle,
      ),
      _SettingsWorkspaceSectionMeta(
        section: _SettingsWorkspaceSection.about,
        icon: AppIcons.info,
        title: l10n.settingsAboutTitle,
        subtitle: l10n.settingsAboutSubtitle,
      ),
    ];
    final currentSection = sections.firstWhere(
      (section) => section.section == _currentSection,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1040;
          final content = AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_currentSection),
              child: switch (_currentSection) {
                _SettingsWorkspaceSection.appearance =>
                  const _AppearanceSettingsView(),
                _SettingsWorkspaceSection.application =>
                  const _ApplicationSettingsView(),
                _SettingsWorkspaceSection.about => const _AboutSettingsView(),
              },
            ),
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 308,
                          child: _SettingsWorkspaceSidebar(
                            sections: sections,
                            currentSection: _currentSection,
                            onSelected: _selectSection,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: content),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SettingsWorkspaceCompactNav(
                          sections: sections,
                          currentSection: _currentSection,
                          onSelected: _selectSection,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSection.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentSection.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsWorkspaceSectionMeta {
  final _SettingsWorkspaceSection section;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsWorkspaceSectionMeta({
    required this.section,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _SettingsWorkspaceSidebar extends StatelessWidget {
  final List<_SettingsWorkspaceSectionMeta> sections;
  final _SettingsWorkspaceSection currentSection;
  final ValueChanged<_SettingsWorkspaceSection> onSelected;

  const _SettingsWorkspaceSidebar({
    required this.sections,
    required this.currentSection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.tertiaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const AppLogoWidget(size: 54),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                for (final section in sections) ...[
                  _SettingsWorkspaceSectionButton(
                    icon: section.icon,
                    title: section.title,
                    subtitle: section.subtitle,
                    selected: currentSection == section.section,
                    onTap: () => onSelected(section.section),
                  ),
                  if (section != sections.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsWorkspaceCompactNav extends StatelessWidget {
  final List<_SettingsWorkspaceSectionMeta> sections;
  final _SettingsWorkspaceSection currentSection;
  final ValueChanged<_SettingsWorkspaceSection> onSelected;

  const _SettingsWorkspaceCompactNav({
    required this.sections,
    required this.currentSection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final section in sections)
            _SettingsWorkspaceCompactChip(
              icon: section.icon,
              label: section.title,
              selected: currentSection == section.section,
              onTap: () => onSelected(section.section),
            ),
        ],
      ),
    );
  }
}

class _SettingsWorkspaceSectionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsWorkspaceSectionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.34)
                  : colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsWorkspaceCompactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsWorkspaceCompactChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SettingsSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SettingsSurfaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSurfaceCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _AppearanceSettingsView extends ConsumerWidget {
  const _AppearanceSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final palettes = <_AccentPaletteOption>[
      _AccentPaletteOption(
        label: l10n.settingsAccentOrchid,
        color: const Color(0xFF6750A4),
      ),
      _AccentPaletteOption(
        label: l10n.settingsAccentLagoon,
        color: const Color(0xFF0061A4),
      ),
      _AccentPaletteOption(
        label: l10n.settingsAccentGrove,
        color: const Color(0xFF006E1C),
      ),
      _AccentPaletteOption(
        label: l10n.settingsAccentEmber,
        color: const Color(0xFF914D00),
      ),
      _AccentPaletteOption(
        label: l10n.settingsAccentCoral,
        color: const Color(0xFF9C4275),
      ),
      _AccentPaletteOption(
        label: l10n.settingsAccentTide,
        color: const Color(0xFF006A6A),
      ),
    ];

    return _DesktopScrollHost(
      builder: (context, controller, physics) => ListView(
        controller: controller,
        physics: physics,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _SettingsSectionHeader(
            title: l10n.settingsAppearanceTitle,
            subtitle: l10n.settingsAppearanceSubtitle,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final settingsColumn = Column(
                children: [
                  _SettingsSurfaceCard(
                    title: l10n.settingsThemeModeTitle,
                    subtitle: l10n.settingsThemeModeSubtitle,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_rounded),
                          label: Text(l10n.themeLight),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.brightness_auto_rounded),
                          label: Text(l10n.themeSystem),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_rounded),
                          label: Text(l10n.themeDark),
                        ),
                      ],
                      selected: <ThemeMode>{settings.themeMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          notifier.setThemeMode(selection.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSurfaceCard(
                    title: l10n.settingsAccentTitle,
                    subtitle: l10n.settingsAccentSubtitle,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final palette in palettes)
                          _AccentPaletteTile(
                            option: palette,
                            selected:
                                settings.seedColor.toARGB32() ==
                                palette.color.toARGB32(),
                            onTap: () => notifier.setSeedColor(palette.color),
                          ),
                      ],
                    ),
                  ),
                ],
              );

              final previewCard = _SettingsSurfaceCard(
                title: l10n.settingsPreviewTitle,
                subtitle: l10n.settingsPreviewSubtitle,
                child: _ThemePreviewSurface(settings: settings),
              );

              if (!isWide) {
                return Column(
                  children: [
                    settingsColumn,
                    const SizedBox(height: 16),
                    previewCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: settingsColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 9, child: previewCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicationSettingsView extends ConsumerWidget {
  const _ApplicationSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return _DesktopScrollHost(
      builder: (context, controller, physics) => ListView(
        controller: controller,
        physics: physics,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _SettingsSectionHeader(
            title: l10n.settingsApplicationTitle,
            subtitle: l10n.settingsApplicationSubtitle,
          ),
          const SizedBox(height: 20),
          _SettingsSurfaceCard(
            title: l10n.settingsLanguageTitle,
            subtitle: l10n.settingsLanguageSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<String>(
                      value: 'ru',
                      icon: const Icon(Icons.translate_rounded),
                      label: Text(l10n.settingsLanguageRussian),
                    ),
                    ButtonSegment<String>(
                      value: 'en',
                      icon: const Icon(Icons.language_rounded),
                      label: Text(l10n.settingsLanguageEnglish),
                    ),
                  ],
                  selected: <String>{settings.locale.languageCode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      notifier.setLocale(Locale(selection.first));
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.g_translate_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          settings.locale.languageCode == 'ru'
                              ? l10n.settingsLanguageRussian
                              : l10n.settingsLanguageEnglish,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentPaletteOption {
  final String label;
  final Color color;

  const _AccentPaletteOption({required this.label, required this.color});
}

class _AccentPaletteTile extends StatelessWidget {
  final _AccentPaletteOption option;
  final bool selected;
  final VoidCallback onTap;

  const _AccentPaletteTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final samples = <Color>[
      option.color,
      Color.lerp(option.color, Colors.white, 0.45)!,
      Color.lerp(option.color, Colors.black, 0.18)!,
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 168,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? option.color.withValues(alpha: 0.16)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? option.color
                  : colorScheme.outlineVariant.withValues(alpha: 0.24),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: option.color),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var index = 0; index < samples.length; index++) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: samples[index],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    if (index < samples.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSettingsView extends StatelessWidget {
  const _AboutSettingsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return _DesktopScrollHost(
      builder: (context, controller, physics) => ListView(
        controller: controller,
        physics: physics,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _SettingsSectionHeader(
            title: l10n.settingsAboutTitle,
            subtitle: l10n.settingsAboutSubtitle,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final heroCard = Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                      colorScheme.tertiaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogoWidget(size: 108),
                    const SizedBox(height: 24),
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aboutTagline,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _SettingsInfoPill(
                          icon: Icons.sell_outlined,
                          label: '${l10n.aboutVersionTitle}: $kAppVersionLabel',
                        ),
                        _SettingsInfoPill(
                          icon: Icons.person_outline_rounded,
                          label: '${l10n.aboutDeveloperTitle}: Qurie',
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final supportCard = _SettingsSurfaceCard(
                title: l10n.aboutSupportTitle,
                subtitle: l10n.aboutSupportSubtitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.coffee_rounded,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              l10n.aboutSupportSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              _openExternalLink(context, kProjectGitHubUri),
                          icon: const Icon(Icons.code_rounded),
                          label: Text(l10n.aboutOpenGitHub),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _openExternalLink(context, kProjectBoostyUri),
                          icon: const Icon(Icons.coffee_rounded),
                          label: Text(l10n.aboutOpenBoosty),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [heroCard, const SizedBox(height: 16), supportCard],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: heroCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 9, child: supportCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewSurface extends StatelessWidget {
  final AppSettingsState settings;

  const _ThemePreviewSurface({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = switch (settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final previewTheme = AppTheme.createTheme(brightness, settings.seedColor);
    final scheme = previewTheme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.window_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsPreviewWindowTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewChip(
                      label: l10n.settingsPreviewChip,
                      backgroundColor: scheme.surface.withValues(alpha: 0.82),
                      foregroundColor: scheme.onSurface,
                    ),
                    _PreviewChip(
                      label: brightness == Brightness.dark
                          ? l10n.themeDark
                          : l10n.themeLight,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.homeTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.settingsPreviewClientName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  icon: const Icon(Icons.north_east_rounded),
                  label: Text(l10n.settingsPreviewAction),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _PreviewChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingsInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
