import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow_qaddons_manager/core/theme/app_theme.dart';
import 'package:wow_qaddons_manager/shared/widgets/app_logo_widget.dart';
import 'package:wow_qaddons_manager/data/services/wow_scanner_service.dart';
import 'package:wow_qaddons_manager/data/repositories/client_repository.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_client.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/data/services/addon_search_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_installer_service.dart';
import 'package:wow_qaddons_manager/data/services/addon_registry_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

const bool kShowPerformanceOverlay = bool.fromEnvironment('SHOW_PERFORMANCE_OVERLAY');

// Провайдеры
final scannerServiceProvider = Provider((ref) => WoWScannerService());
final clientRepositoryProvider = Provider((ref) => ClientRepository());
final curseForgeClientProvider = Provider((ref) => CurseForgeClient());

final addonSearchServiceProvider = Provider((ref) {
  final cfClient = ref.read(curseForgeClientProvider);
  return AddonSearchService([
    CurseForgeProvider(cfClient),
    GitHubProvider(),
  ]);
});

final addonInstallerServiceProvider = Provider((ref) => AddonInstallerService());
final addonRegistryServiceProvider = Provider((ref) => AddonRegistryService());

// Состояние установленных аддонов
class LocalAddonsNotifier extends StateNotifier<AsyncValue<List<InstalledAddonGroup>>> {
  final AddonInstallerService _installer;
  final AddonRegistryService _registry;
  final GameClient _client;
  LocalAddonsNotifier(this._installer, this._registry, this._client) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final scannedFolders = await _installer.scanInstalledFolders(_client);
      final addons = await _registry.loadAddonGroups(_client, scannedFolders);
      state = AsyncValue.data(addons);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> registerInstalledAddon(AddonItem addon, List<String> installedFolders) async {
    try {
      await _registry.registerInstallation(
        _client,
        addon: addon,
        installedFolders: installedFolders,
      );
      await refresh();
    } catch (e) {
      await refresh();
      rethrow;
    }
  }

  Future<void> deleteAddon(InstalledAddonGroup group) async {
    try {
      await _installer.deleteAddon(_client, group);
      await _registry.removeGroup(_client, group);
      await refresh();
    } catch (e) {
      await refresh();
      rethrow;
    }
  }

  Future<void> deleteAddons(List<InstalledAddonGroup> groups) async {
    try {
      for (final group in groups) {
        await _installer.deleteAddon(_client, group);
        await _registry.removeGroup(_client, group);
      }
      await refresh();
    } catch (e) {
      await refresh();
      rethrow;
    }
  }
}

final localAddonsProvider = StateNotifierProvider.family<LocalAddonsNotifier, AsyncValue<List<InstalledAddonGroup>>, GameClient>((ref, client) {
  return LocalAddonsNotifier(
    ref.read(addonInstallerServiceProvider),
    ref.read(addonRegistryServiceProvider),
    client,
  );
});

// Состояние поиска аддонов
class SearchResultsNotifier extends StateNotifier<AsyncValue<List<AddonItem>>> {
  final AddonSearchService _searchService;
  SearchResultsNotifier(this._searchService) : super(const AsyncValue.data([]));

  Future<void> search(String query, {required String gameVersion}) async {
    if (query.isEmpty || gameVersion.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      // Провайдеры уже обернуты в catchError внутри сервиса, но добавим доп. защиту
      final results = await _searchService.searchAll(query, gameVersion);
      state = AsyncValue.data(results);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final searchResultsProvider = StateNotifierProvider<SearchResultsNotifier, AsyncValue<List<AddonItem>>>((ref) {
  return SearchResultsNotifier(ref.read(addonSearchServiceProvider));
});

class ClientListNotifier extends StateNotifier<List<GameClient>> {
  final ClientRepository _repository;
  ClientListNotifier(this._repository) : super([]) {
    loadClients();
  }

  Future<void> loadClients() async {
    state = await _repository.getClients();
  }

  Future<void> addClient(GameClient client) async {
    await _repository.saveClient(client);
    await loadClients();
  }

  Future<void> removeClient(String id) async {
    await _repository.removeClient(id);
    await loadClients();
  }
}

final clientListProvider = StateNotifierProvider<ClientListNotifier, List<GameClient>>((ref) {
  return ClientListNotifier(ref.read(clientRepositoryProvider));
});

class AppIcons {
  static const IconData interface = Icons.tune_rounded;
  static const IconData wow = Icons.videogame_asset_rounded;
  static const IconData downloads = Icons.download_rounded;
  static const IconData info = Icons.info_rounded;
}

// Localization Stub
class AppLocalizationsStub {
  static String appTitle(String locale) => locale == 'ru' ? 'WoW QAddOns Менеджер' : 'WoW QAddOns Manager';
  static String homeTitle(String locale) => locale == 'ru' ? 'Клиенты WoW' : 'WoW Clients';
  static String settingsTitle(String locale) => locale == 'ru' ? 'Настройки' : 'Settings';
  static String interfaceSection(String locale) => locale == 'ru' ? 'Интерфейс' : 'Interface';
  static String languageSection(String locale) => locale == 'ru' ? 'Язык' : 'Language';
  static String themeModeLabel(String locale) => locale == 'ru' ? 'Тема оформления' : 'Theme Mode';
  static String colorSchemeLabel(String locale) => locale == 'ru' ? 'Цветовая схема' : 'Color Scheme';
  static String wowClientsSection(String locale) => locale == 'ru' ? 'Клиенты WoW' : 'WoW Clients';
  static String downloadsSection(String locale) => locale == 'ru' ? 'Загрузки' : 'Downloads';
  static String aboutSection(String locale) => locale == 'ru' ? 'О приложении' : 'About';
  static String versionLabel(String locale) => locale == 'ru' ? 'Версия' : 'Version';
  static String developerLabel(String locale) => locale == 'ru' ? 'Разработчик' : 'Developer';
  static String descriptionLabel(String locale) => locale == 'ru' ? 'Управляйте своими аддонами' : 'Manage your addons';
  static String scanFailed(String locale) => locale == 'ru' ? 'Клиент WoW не найден' : 'WoW client not found';

  static String missingDataFolder(String locale) => 
    locale == 'ru' ? 'В папке отсутствует директория "Data"' : 'Folder "Data" is missing';
  static String missingExeFile(String locale) => 
    locale == 'ru' ? 'Исполняемый файл (.exe) не найден' : 'Executable file (.exe) not found';
  static String selectVersionTitle(String locale) => 
    locale == 'ru' ? 'Выберите версию игры' : 'Select Game Version';

  static String scanSuccess(String locale, String ver) => locale == 'ru' ? 'Добавлен: $ver' : 'Added: $ver';
  static String manageAddons(String locale) => locale == 'ru' ? 'Управление аддонами' : 'Manage Addons';
  static String emptyClients(String locale) => locale == 'ru' ? 'Список клиентов пуст' : 'No clients found';
  static String searchAddons(String locale) => locale == 'ru' ? 'Поиск аддонов...' : 'Search addons...';
  static String installing(String locale) => locale == 'ru' ? 'Установка...' : 'Installing...';
  static String install(String locale) => locale == 'ru' ? 'Установить' : 'Install';
  static String versionNotFound(String locale, String version) =>
    locale == 'ru'
      ? 'Файл не найден для версии $version (или совместимой)'
      : 'No file found for version $version (or compatible)';
  static String installSuccess(String locale) => locale == 'ru' ? 'Аддон успешно установлен' : 'Addon installed successfully';
  static String installError(String locale) => locale == 'ru' ? 'Ошибка' : 'Error';
  static String myAddons(String locale) => locale == 'ru' ? 'Мои аддоны' : 'My Addons';
  static String delete(String locale) => locale == 'ru' ? 'Удалить' : 'Delete';
  static String confirmDeleteTitle(String locale) => locale == 'ru' ? 'Удалить аддон?' : 'Delete addon?';
  static String confirmDeleteMessage(String locale, String name) => locale == 'ru' ? 'Вы уверены, что хотите удалить $name?' : 'Are you sure you want to delete $name?';
  static String cancel(String locale) => locale == 'ru' ? 'Отмена' : 'Cancel';
  static String noLocalAddons(String locale) => locale == 'ru' ? 'Установленные аддоны не найдены' : 'No installed addons found';
  static String scanAddons(String locale) => locale == 'ru' ? 'Сканировать' : 'Scan';
  static String refreshAddons(String locale) => locale == 'ru' ? 'Обновить список' : 'Refresh list';
  static String deleteSelected(String locale) => locale == 'ru' ? 'Удалить выбранные' : 'Delete selected';
  static String selectedCount(String locale, int count) => locale == 'ru' ? 'Выбрано: $count' : 'Selected: $count';
  static String addonFolders(String locale, int count) => locale == 'ru' ? 'Папок: $count' : 'Folders: $count';
  static String localManual(String locale) => locale == 'ru' ? 'Вручную' : 'Manual';
  static String clearSelection(String locale) => locale == 'ru' ? 'Снять выбор' : 'Clear selection';
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('ENV file not found or failed to load: $e');
  }

  final sharedPrefs = await SharedPreferences.getInstance();
  
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(sharedPrefs),
    ],
    child: const MyApp(),
  ));
}

// Провайдер для SharedPreferences
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

// App Theme State
class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final Color seedColor;

  AppSettingsState({required this.themeMode, required this.locale, required this.seedColor});

  AppSettingsState copyWith({ThemeMode? themeMode, Locale? locale, Color? seedColor}) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  AppSettingsNotifier(this._prefs) : super(AppSettingsState(
    themeMode: ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index],
    locale: Locale(_prefs.getString('locale') ?? 'en'),
    seedColor: Color(_prefs.getInt('seedColor') ?? 0xFF6750A4),
  ));

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setInt('themeMode', mode.index);
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
    _prefs.setString('locale', locale.languageCode);
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
    _prefs.setInt('seedColor', color.toARGB32());
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier(ref.watch(sharedPrefsProvider));
});

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
      locale: settings.locale,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleScan(BuildContext context, WidgetRef ref, String locale) async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: locale == 'ru' ? 'Выберите папку с World of Warcraft' : 'Select World of Warcraft folder',
    );

    if (directoryPath == null) return;

    final scanner = ref.read(scannerServiceProvider);
    
    List<GameClient> clients;
    try {
      clients = await scanner.scanDirectory(directoryPath);
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
          title: Text(locale == 'ru' ? 'Выберите файл запуска' : 'Select executable'),
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
        selectedClient = selectedClient.copyWith(
          version: manualVersion,
          displayName: 'World of Warcraft $manualVersion',
        );
      } else {
        return;
      }
    }

    await ref.read(clientListProvider.notifier).addClient(selectedClient);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizationsStub.scanSuccess(locale, selectedClient.version)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizationsStub.appTitle(locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
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
                  Text(AppLocalizationsStub.emptyClients(locale), style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisExtent: 220,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: clients.length,
              itemBuilder: (context, index) => RepaintBoundary(
                child: _ClientCard(client: clients[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleScan(context, ref, locale),
        icon: const Icon(Icons.add_rounded),
        label: Text(locale == 'ru' ? 'Добавить клиент' : 'Add Client'),
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
      '1.12.1', '2.4.3', '3.3.5', '4.3.4', '5.4.8', '6.2.4', '7.3.5', '8.3.7', '9.2.7', '10.2.7', '11.0.0'
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
          MaterialPageRoute(builder: (context) => ClientDetailsScreen(client: client)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                ],
              ),
              const Spacer(),
              Text(
                client.displayName ?? 'World of Warcraft',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                client.path,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ClientDetailsScreen(client: client)),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  ConsumerState<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<_LocalAddonsViewState> _localAddonsKey = GlobalKey<_LocalAddonsViewState>();
  int _currentIndex = 0;
  int _selectedLocalAddons = 0;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? AppLocalizationsStub.selectedCount(locale, _selectedLocalAddons)
              : (widget.client.displayName ?? 'Client Details'),
        ),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              tooltip: AppLocalizationsStub.deleteSelected(locale),
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _localAddonsKey.currentState?.deleteSelectedFromAppBar(),
            ),
            IconButton(
              tooltip: AppLocalizationsStub.clearSelection(locale),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _localAddonsKey.currentState?.clearSelection(),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await ref.read(clientListProvider.notifier).removeClient(widget.client.id);
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
                client: widget.client,
                onSelectionChanged: (count) {
                  if (_selectedLocalAddons != count) {
                    setState(() => _selectedLocalAddons = count);
                  }
                },
              ),
              _SearchAddonsView(client: widget.client),
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
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
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
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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

  Future<void> deleteSelectedFromAppBar() async {
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    final groups = ref.read(localAddonsProvider(widget.client)).valueOrNull ?? const <InstalledAddonGroup>[];
    final selectedGroups = groups.where((group) => _selectedIds.contains(group.id)).toList();
    if (selectedGroups.isEmpty) {
      clearSelection();
      return;
    }

    await _handleDeleteGroups(selectedGroups, locale);
  }

  Future<void> _handleDeleteGroups(List<InstalledAddonGroup> groups, String locale) async {
    final theme = Theme.of(context);
    final displayName = groups.length == 1
        ? groups.first.displayName
        : AppLocalizationsStub.selectedCount(locale, groups.length);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizationsStub.confirmDeleteTitle(locale)),
        content: Text(AppLocalizationsStub.confirmDeleteMessage(locale, displayName)),
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
        await ref.read(localAddonsProvider(widget.client).notifier).deleteAddon(groups.first);
      } else {
        await ref.read(localAddonsProvider(widget.client).notifier).deleteAddons(groups);
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

  Widget _buildActionBar(BuildContext context, String locale) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelectionMode = _selectedIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelectionMode ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isSelectionMode ? colorScheme.primary : colorScheme.outlineVariant).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelectionMode ? Icons.checklist_rounded : Icons.inventory_2_rounded,
              color: isSelectionMode ? colorScheme.onPrimaryContainer : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelectionMode
                        ? AppLocalizationsStub.selectedCount(locale, _selectedIds.length)
                        : AppLocalizationsStub.myAddons(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelectionMode ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                        ),
                  ),
                  Text(
                    isSelectionMode
                        ? AppLocalizationsStub.deleteSelected(locale)
                        : AppLocalizationsStub.refreshAddons(locale),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelectionMode
                              ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: AppLocalizationsStub.scanAddons(locale),
              onPressed: () => ref.read(localAddonsProvider(widget.client).notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
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
    final colorScheme = Theme.of(context).colorScheme;
    final addonsAsync = ref.watch(localAddonsProvider(widget.client));

    return Column(
      children: [
        _ClientHeader(client: widget.client),
        _buildActionBar(context, locale),
        const SizedBox(height: 16),
        Expanded(
          child: addonsAsync.when(
            data: (addons) {
              _syncSelection(addons);

              if (addons.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => ref.read(localAddonsProvider(widget.client).notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizationsStub.noLocalAddons(locale),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(localAddonsProvider(widget.client).notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                  itemCount: addons.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addon = addons[index];
                    final isSelected = _selectedIds.contains(addon.id);

                    return RepaintBoundary(
                      child: Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        color: isSelected
                            ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
                            : colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: (isSelected ? colorScheme.secondary : colorScheme.outlineVariant).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
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
                                      addon.isManaged ? Icons.cloud_done_rounded : Icons.folder_rounded,
                                      color: addon.isManaged
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addon.displayName,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                              label: AppLocalizationsStub.addonFolders(
                                                locale,
                                                addon.installedFolders.length,
                                              ),
                                            ),
                                            _InfoChip(
                                              icon: addon.isManaged ? Icons.link_rounded : Icons.home_repair_service_rounded,
                                              label: addon.providerName ?? AppLocalizationsStub.localManual(locale),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.subdirectory_arrow_right_rounded, color: colorScheme.primary),
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
                                  onPressed: () => _handleDeleteGroups([addon], locale),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: Text(AppLocalizationsStub.delete(locale)),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

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

class _SearchAddonsView extends ConsumerStatefulWidget {
  final GameClient client;
  const _SearchAddonsView({required this.client});

  @override
  ConsumerState<_SearchAddonsView> createState() => _SearchAddonsViewState();
}

class _SearchAddonsViewState extends ConsumerState<_SearchAddonsView> {
  final TextEditingController _searchController = TextEditingController();
  final _debounce = _Debouncer(milliseconds: 500);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final searchResults = ref.watch(searchResultsProvider);

    return Column(
      children: [
        _ClientHeader(client: widget.client),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SearchBar(
            controller: _searchController,
            hintText: AppLocalizationsStub.searchAddons(locale),
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchResultsProvider.notifier).search('', gameVersion: widget.client.version);
                  },
                ),
            ],
            onChanged: (value) {
              _debounce.run(() {
                ref.read(searchResultsProvider.notifier).search(value, gameVersion: widget.client.version);
              });
              setState(() {});
            },
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainer),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: searchResults.when(
            data: (mods) {
              if (mods.isEmpty && _searchController.text.isEmpty) {
                return Center(
                  child: Text(
                    locale == 'ru' ? 'Введите название аддона' : 'Enter addon name',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                itemCount: mods.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => RepaintBoundary(
                  child: AddonSearchResultTile(
                    mod: mods[index],
                    client: widget.client,
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      client.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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

class AddonSearchResultTile extends ConsumerStatefulWidget {
  final AddonItem mod;
  final GameClient client;
  final ValueChanged<List<String>>? onInstalled;
  const AddonSearchResultTile({super.key, required this.mod, required this.client, this.onInstalled});

  @override
  ConsumerState<AddonSearchResultTile> createState() => _AddonSearchResultTileState();
}

class _AddonSearchResultTileState extends ConsumerState<AddonSearchResultTile> {
  bool _isInstalling = false;

  Future<void> _handleInstall() async {
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    setState(() => _isInstalling = true);

    try {
      final searchService = ref.read(addonSearchServiceProvider);
      final installer = ref.read(addonInstallerServiceProvider);

      final info = await searchService.getDownloadInfo(widget.mod, widget.client.version);

      if (!mounted) return;

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizationsStub.versionNotFound(locale, widget.client.version)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        final result = await installer.installAddon(info.url, info.fileName, widget.client);
        await ref
            .read(localAddonsProvider(widget.client).notifier)
            .registerInstalledAddon(widget.mod, result.installedFolders);
        widget.onInstalled?.call(result.installedFolders);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizationsStub.installSuccess(locale)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizationsStub.installError(locale)}: $e'),
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
    final locale = ref.watch(appSettingsProvider).locale.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.mod.thumbnailUrl ?? '',
                    width: 64,
                    height: 64,
                    cacheWidth: 128,
                    cacheHeight: 128,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.extension_rounded, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                      if (widget.mod.author != null)
                        Expanded(
                          child: Text(
                            'by ${widget.mod.providerName == 'GitHub' ? '@' : ''}${widget.mod.author}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'Ver: ${widget.mod.version}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.mod.summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.tonal(
              onPressed: _isInstalling ? null : _handleInstall,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback callback) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), callback);
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
          Icon(icon, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
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
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
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
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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
                        ? Border.all(color: Theme.of(context).colorScheme.outline, width: 4)
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
                  child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 32) : null,
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
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
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

  const _ThemeOption({required this.icon, required this.isSelected, required this.onTap});

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
            color: isSelected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colorScheme.secondary : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
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
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 32),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WoW QAddOns Team',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Open Source Developers',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
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
