import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';
import 'package:wow_qaddons_manager/core/l10n/app_localizations.dart';
import 'package:wow_qaddons_manager/core/theme/app_theme.dart';
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

class AppIcons {
  static const IconData interface = Icons.tune_rounded;
  static const IconData wow = Icons.videogame_asset_rounded;
  static const IconData downloads = Icons.download_rounded;
  static const IconData info = Icons.info_rounded;
}

// Localization Stub
class AppLocalizationsStub {
  static String appTitle(String locale) =>
      locale == 'ru' ? 'WoW QAddOns Менеджер' : 'WoW QAddOns Manager';
  static String homeTitle(String locale) =>
      locale == 'ru' ? 'Клиенты WoW' : 'WoW Clients';
  static String settingsTitle(String locale) =>
      locale == 'ru' ? 'Настройки' : 'Settings';
  static String interfaceSection(String locale) =>
      locale == 'ru' ? 'Интерфейс' : 'Interface';
  static String languageSection(String locale) =>
      locale == 'ru' ? 'Язык' : 'Language';
  static String themeModeLabel(String locale) =>
      locale == 'ru' ? 'Тема оформления' : 'Theme Mode';
  static String colorSchemeLabel(String locale) =>
      locale == 'ru' ? 'Цветовая схема' : 'Color Scheme';
  static String wowClientsSection(String locale) =>
      locale == 'ru' ? 'Клиенты WoW' : 'WoW Clients';
  static String downloadsSection(String locale) =>
      locale == 'ru' ? 'Загрузки' : 'Downloads';
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
      title: AppLocalizationsStub.appTitle(settings.locale.languageCode),
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
    final clients = ref.watch(clientListProvider);

    return PerformanceTrackedScope(
      screenName: 'Home',
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizationsStub.appTitle(locale)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
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
            const SizedBox(width: 8),
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
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                addRepaintBoundaries: false,
                addAutomaticKeepAlives: false,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: clients.length,
                itemBuilder: (context, index) =>
                    RepaintBoundary(child: _ClientCard(client: clients[index])),
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

class _ClientCard extends ConsumerWidget {
  final GameClient client;
  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDetailsScreen(client: client),
          ),
        ),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      client.type.name.toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${AppLocalizationsStub.versionLabel(locale)} ${client.version}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizationsStub.renameClient(locale),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _promptRenameClient(context, ref, client, locale),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                client.resolvedDisplayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                client.path,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientDetailsScreen(client: client),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppLocalizationsStub.manageAddons(locale)),
              ),
            ],
          ),
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
  final PageController _pageController = PageController();
  final GlobalKey<_LocalAddonsViewState> _localAddonsKey =
      GlobalKey<_LocalAddonsViewState>();
  late GameClient _client;
  int _currentIndex = 0;
  int _selectedLocalAddons = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final isSelectionMode = _currentIndex == 0 && _selectedLocalAddons > 0;

    return PerformanceTrackedScope(
      screenName: 'ClientDetails',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isSelectionMode
                ? AppLocalizationsStub.selectedCount(
                    locale,
                    _selectedLocalAddons,
                  )
                : _client.resolvedDisplayName,
          ),
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
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _LocalAddonsView(
                  key: _localAddonsKey,
                  client: _client,
                  onSelectionChanged: (count) {
                    if (_selectedLocalAddons != count) {
                      setState(() => _selectedLocalAddons = count);
                    }
                  },
                ),
                _SearchAddonsView(client: _client),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: _ClientDetailsNavBar(
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
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ClientDetailsNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              onTap: () => onTap(0),
            ),
            _DetailsNavItem(
              icon: Icons.search_rounded,
              isSelected: currentIndex == 1,
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
  final VoidCallback onTap;

  const _DetailsNavItem({
    required this.icon,
    required this.isSelected,
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
              color: isSelected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimary
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

    return Column(
      children: [
        _ClientHeader(client: widget.client),
        _buildActionBar(context, locale, currentAddons),
        const SizedBox(height: 16),
        Expanded(
          child: addonsAsync.when(
            data: (addons) {
              _syncSelection(addons);

              if (addons.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(localAddonsProvider(widget.client).notifier)
                      .refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizationsStub.noLocalAddons(locale),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref
                    .read(localAddonsProvider(widget.client).notifier)
                    .refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                  addRepaintBoundaries: false,
                  addAutomaticKeepAlives: false,
                  itemCount: addons.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addon = addons[index];
                    final isSelected = _selectedIds.contains(addon.id);

                    return RepaintBoundary(
                      child: Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        color: isSelected
                            ? colorScheme.secondaryContainer.withValues(
                                alpha: 0.55,
                              )
                            : colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color:
                                (isSelected
                                        ? colorScheme.secondary
                                        : colorScheme.outlineVariant)
                                    .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            backgroundColor: Colors.transparent,
                            collapsedBackgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              16,
                            ),
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(addon.id),
                            ),
                            title: GestureDetector(
                              onLongPress: () => _toggleSelection(addon.id),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: addon.isManaged
                                        ? colorScheme.primaryContainer
                                        : colorScheme.secondaryContainer,
                                    child: Icon(
                                      addon.isManaged
                                          ? Icons.cloud_done_rounded
                                          : Icons.folder_rounded,
                                      color: addon.isManaged
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addon.displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _InfoChip(
                                              icon: Icons.folder_copy_outlined,
                                              label:
                                                  AppLocalizationsStub.addonFolders(
                                                    locale,
                                                    addon
                                                        .installedFolders
                                                        .length,
                                                  ),
                                            ),
                                            _InfoChip(
                                              icon: addon.isManaged
                                                  ? Icons.link_rounded
                                                  : Icons
                                                        .home_repair_service_rounded,
                                              label:
                                                  addon.providerName == 'Manual'
                                                  ? AppLocalizationsStub.localManual(
                                                      locale,
                                                    )
                                                  : addon.providerName ??
                                                        AppLocalizationsStub.localManual(
                                                          locale,
                                                        ),
                                            ),
                                            if ((addon.version ?? '')
                                                .isNotEmpty)
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
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.55),
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
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
                                  onPressed: () =>
                                      _handleDeleteGroups([addon], locale),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: Text(
                                    AppLocalizationsStub.delete(locale),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () =>
                _LoadingState(label: l10n.clientDetailsLoadingAddons),
            error: (e, s) => _StatusMessage(
              icon: Icons.error_outline_rounded,
              title: l10n.clientDetailsLoadErrorTitle,
              message: l10n.clientDetailsLoadErrorMessage(_formatError(e)),
            ),
          ),
        ),
      ],
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
  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');

  ClientSearchScopeKey get _scopeKey => ClientSearchScopeKey(
    clientId: widget.client.id,
    gameVersion: widget.client.version,
  );

  String get _normalizedQuery => _queryNotifier.value;

  @override
  void dispose() {
    _searchController.dispose();
    _queryNotifier.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _queryNotifier.value = '';
    ref.invalidate(searchResultsProvider(_scopeKey));
  }

  void _handleQueryChanged(String value) {
    final normalizedValue = value.trim();
    _queryNotifier.value = normalizedValue;

    if (normalizedValue.isEmpty) {
      ref.invalidate(searchResultsProvider(_scopeKey));
      return;
    }

    ref
        .read(searchResultsProvider(_scopeKey).notifier)
        .search(normalizedValue, gameVersion: widget.client.version);
  }

  Widget _buildDiscoveryFeed() {
    return _DiscoveryFeedContent(client: widget.client, scopeKey: _scopeKey);
  }

  Widget _buildSearchResults() {
    return _SearchResultsContent(
      client: widget.client,
      scopeKey: _scopeKey,
      query: _normalizedQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _ClientHeader(client: widget.client),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SearchBar(
            controller: _searchController,
            hintText: l10n.searchAddonsHint,
            leading: const Icon(Icons.search_rounded),
            trailing: [
              ValueListenableBuilder<String>(
                valueListenable: _queryNotifier,
                builder: (context, query, _) {
                  if (query.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: _clearSearch,
                  );
                },
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
        const SizedBox(height: 16),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _queryNotifier,
            builder: (context, query, _) {
              final isDiscoveryMode = query.isEmpty;
              final sectionTitle = isDiscoveryMode
                  ? l10n.discoveryFeedTitle(widget.client.version)
                  : l10n.searchResultsTitle(query);
              final sectionSubtitle = isDiscoveryMode
                  ? l10n.discoveryFeedSubtitle(widget.client.version)
                  : l10n.searchResultsSubtitle(widget.client.version);

              return PerformanceTrackedScope(
                screenName: isDiscoveryMode
                    ? 'SearchDiscovery'
                    : 'SearchResults',
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _FeedIntroCard(
                        icon: isDiscoveryMode
                            ? Icons.auto_awesome_rounded
                            : Icons.search_rounded,
                        title: sectionTitle,
                        subtitle: sectionSubtitle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isDiscoveryMode
                          ? _buildDiscoveryFeed()
                          : _buildSearchResults(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClientHeader extends StatelessWidget {
  final GameClient client;
  const _ClientHeader({required this.client});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const AppLogoWidget(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppLocalizationsStub.versionLabel(locale)} ${client.version}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      client.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _DiscoveryFeedContent extends ConsumerWidget {
  final GameClient client;
  final ClientSearchScopeKey scopeKey;

  const _DiscoveryFeedContent({required this.client, required this.scopeKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(
      appSettingsProvider.select((state) => state.locale.languageCode),
    );
    final shellState = ref.watch(
      discoveryFeedProvider(scopeKey).select(
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
      return _StatusMessage(
        icon: Icons.cloud_off_rounded,
        title: l10n.discoveryFeedErrorTitle,
        message: l10n.discoveryFeedErrorMessage(
          client.version,
          _formatError(shellState.error!),
        ),
        actionLabel: l10n.retryButton,
        onAction: () =>
            ref.read(discoveryFeedProvider(scopeKey).notifier).load(),
      );
    }

    if (shellState.isInitialLoading) {
      return _LoadingState(label: l10n.discoveryFeedLoading(client.version));
    }

    if (!shellState.hasResults) {
      return _StatusMessage(
        icon: Icons.travel_explore_rounded,
        title: l10n.discoveryFeedEmptyTitle,
        message: l10n.discoveryFeedEmptyMessage(client.version),
        actionLabel: shellState.canLoadMore
            ? AppLocalizationsStub.loadMore(locale)
            : null,
        onAction: shellState.canLoadMore
            ? () =>
                  ref.read(discoveryFeedProvider(scopeKey).notifier).loadMore()
            : null,
      );
    }

    return _VerifiedFeedListSection(
      feedProvider: discoveryFeedProvider(scopeKey),
      client: client,
      showLoadMore: true,
      onLoadMore: () =>
          ref.read(discoveryFeedProvider(scopeKey).notifier).loadMore(),
    );
  }
}

class _SearchResultsContent extends ConsumerWidget {
  final GameClient client;
  final ClientSearchScopeKey scopeKey;
  final String query;

  const _SearchResultsContent({
    required this.client,
    required this.scopeKey,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shellState = ref.watch(
      searchResultsProvider(scopeKey).select(
        (state) => (
          hasResults: state.hasResults,
          hasError: state.hasError && !state.hasResults,
          isInitialLoading: state.isLoading && !state.hasResults,
          error: state.hasError ? state.error : null,
        ),
      ),
    );

    if (shellState.hasError) {
      return _StatusMessage(
        icon: Icons.error_outline_rounded,
        title: l10n.searchErrorTitle,
        message: l10n.searchErrorMessage(_formatError(shellState.error!)),
        actionLabel: l10n.retryButton,
        onAction: () => ref
            .read(searchResultsProvider(scopeKey).notifier)
            .search(query, gameVersion: client.version),
      );
    }

    if (shellState.isInitialLoading) {
      return _LoadingState(label: l10n.searchLoading(query));
    }

    if (!shellState.hasResults) {
      return _StatusMessage(
        icon: Icons.search_off_rounded,
        title: l10n.searchNoResultsTitle,
        message: l10n.searchNoResultsMessage(query, client.version),
      );
    }

    return _VerifiedFeedListSection(
      feedProvider: searchResultsProvider(scopeKey),
      client: client,
    );
  }
}

class _VerifiedFeedListSection extends ConsumerWidget {
  final ProviderListenable<AddonFeedState> feedProvider;
  final GameClient client;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;

  const _VerifiedFeedListSection({
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

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            addRepaintBoundaries: false,
            addAutomaticKeepAlives: false,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final itemKey = '${item.providerName}:${item.originalId}';
              return RepaintBoundary(
                child: _AnimatedFeedEntry(
                  key: ValueKey(itemKey),
                  child: AddonSearchResultTile(
                    mod: item,
                    client: client,
                    localeCode: locale,
                    installedMatch: installedMatches[index],
                  ),
                ),
              );
            },
          ),
        ),
        if (showLoadMore && onLoadMore != null)
          _DiscoveryLoadMoreBar(
            feedProvider: feedProvider,
            onPressed: onLoadMore!,
          ),
        const SizedBox(height: 96),
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

  Future<void> _handleInstall() async {
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    setState(() => _isInstalling = true);

    try {
      final installAddon = ref.read(installAddonUseCaseProvider);
      final localAddonsNotifier = ref.read(
        localAddonsProvider(widget.client).notifier,
      );

      if (!mounted) return;

      final result = await installAddon(
        addon: widget.mod,
        client: widget.client,
      );

      if (!mounted) return;

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
      } else if (result.status == InstallAddonStatus.alreadyInstalled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizationsStub.alreadyInstalled(locale, widget.mod.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else if (result.status == InstallAddonStatus.success) {
        await localAddonsNotifier.refresh();
        if (!mounted) return;
        widget.onInstalled?.call(result.installedFolders);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizationsStub.installSuccess(locale)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
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
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
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
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _AddonThumbnail(url: widget.mod.thumbnailUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.mod.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProviderBadge(providerName: widget.mod.providerName),
                    ],
                  ),
                  Row(
                    children: [
                      if (authorLabel != null)
                        Expanded(
                          child: Text(
                            authorLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.addonVersionLabel(widget.mod.version),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
            if (installedMatch.isInstalled)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.secondary.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizationsStub.installed(locale),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton.tonal(
                onPressed: _isInstalling ? null : _handleInstall,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInstalling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizationsStub.install(locale)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddonThumbnail extends StatelessWidget {
  final String? url;

  const _AddonThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedUrl = url?.trim() ?? '';

    if (normalizedUrl.isEmpty) {
      return _AddonThumbnailPlaceholder(colorScheme: colorScheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        normalizedUrl,
        width: 64,
        height: 64,
        cacheWidth: 128,
        cacheHeight: 128,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) =>
            _AddonThumbnailPlaceholder(colorScheme: colorScheme),
      ),
    );
  }
}

class _AddonThumbnailPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AddonThumbnailPlaceholder({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.extension_rounded, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final String providerName;
  const _ProviderBadge({required this.providerName});

  @override
  Widget build(BuildContext context) {
    final isCF = providerName == 'CurseForge';

    Color bgColor = Colors.grey.shade200;
    Color textColor = Colors.black87;
    Color borderColor = Colors.grey.shade400;

    if (isCF) {
      bgColor = Colors.deepPurple.shade100;
      textColor = Colors.deepPurple.shade900;
      borderColor = Colors.deepPurple.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        providerName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
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
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;

    final titles = [
      AppLocalizationsStub.interfaceSection(locale),
      AppLocalizationsStub.wowClientsSection(locale),
      AppLocalizationsStub.downloadsSection(locale),
      AppLocalizationsStub.aboutSection(locale),
    ];

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(titles[_currentIndex], key: ValueKey(_currentIndex)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: const [
              _InterfaceSettingsView(),
              _EmptySectionPlaceholder(icon: Icons.videogame_asset_outlined),
              _EmptySectionPlaceholder(icon: Icons.download_rounded),
              _AboutSettingsView(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: _FloatingNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionPlaceholder extends StatelessWidget {
  final IconData icon;

  const _EmptySectionPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'Section WIP',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            _NavItem(
              icon: AppIcons.interface,
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: AppIcons.wow,
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: AppIcons.downloads,
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: AppIcons.info,
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
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
              color: isSelected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterfaceSettingsView extends ConsumerWidget {
  const _InterfaceSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final locale = settings.locale.languageCode;

    final List<Color> availableColors = [
      const Color(0xFF6750A4),
      const Color(0xFF0061A4),
      const Color(0xFF006E1C),
      const Color(0xFF914D00),
      const Color(0xFF9C4275),
      const Color(0xFF006A6A),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
      children: [
        _SettingsGroup(
          title: AppLocalizationsStub.languageSection(locale),
          child: Row(
            children: [
              Expanded(
                child: _ChoiceChip<String>(
                  label: 'Русский',
                  value: 'ru',
                  groupValue: locale,
                  onSelected: (val) => notifier.setLocale(const Locale('ru')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceChip<String>(
                  label: 'English',
                  value: 'en',
                  groupValue: locale,
                  onSelected: (val) => notifier.setLocale(const Locale('en')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: AppLocalizationsStub.themeModeLabel(locale),
          child: Row(
            children: [
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                isSelected: settings.themeMode == ThemeMode.light,
                onTap: () => notifier.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 12),
              _ThemeOption(
                icon: Icons.settings_brightness_rounded,
                isSelected: settings.themeMode == ThemeMode.system,
                onTap: () => notifier.setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: 12),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                isSelected: settings.themeMode == ThemeMode.dark,
                onTap: () => notifier.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: AppLocalizationsStub.colorSchemeLabel(locale),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: availableColors.map((color) {
              final isSelected = settings.seedColor == color;
              return GestureDetector(
                onTap: () => notifier.setSeedColor(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 4,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.28),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 32,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onSelected;

  const _ChoiceChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.secondary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AboutSettingsView extends ConsumerWidget {
  const _AboutSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
      children: [
        Center(
          child: Column(
            children: [
              const AppLogoWidget(size: 160),
              const SizedBox(height: 32),
              Text(
                AppLocalizationsStub.appTitle(locale),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizationsStub.versionLabel(locale)}: 1.0.0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _SettingsGroup(
          title: AppLocalizationsStub.developerLabel(locale),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WoW QAddOns Team',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Open Source Developers',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
