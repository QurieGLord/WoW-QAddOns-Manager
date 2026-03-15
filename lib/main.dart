import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/core/theme/app_theme.dart';

// Временная заглушка локализации до исправления генерации в следующей итерации
class AppLocalizationsStub {
  static String appTitle(String locale) => locale == 'ru' ? 'WoW QAddOns Менеджер' : 'WoW QAddOns Manager';
  static String homeTitle(String locale) => locale == 'ru' ? 'Панель управления' : 'Dashboard';
  static String settingsTitle(String locale) => locale == 'ru' ? 'Настройки' : 'Settings';
  static String interfaceSection(String locale) => locale == 'ru' ? 'Интерфейс' : 'Interface';
  static String languageSection(String locale) => locale == 'ru' ? 'Язык' : 'Language';
  static String themeModeLabel(String locale) => locale == 'ru' ? 'Тема оформления' : 'Theme Mode';
  static String colorSchemeLabel(String locale) => locale == 'ru' ? 'Цветовая схема' : 'Color Scheme';
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

// Модель настроек
class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final Color seedColor;

  AppSettingsState({
    required this.themeMode,
    required this.locale,
    required this.seedColor,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    Color? seedColor,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

// Провайдер настроек
class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(AppSettingsState(
    themeMode: ThemeMode.system,
    locale: const Locale('en'),
    seedColor: Colors.deepPurple,
  ));

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setLocale(Locale locale) => state = state.copyWith(locale: locale);
  void setSeedColor(Color color) => state = state.copyWith(seedColor: color);
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final locale = settings.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizationsStub.appTitle(locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizationsStub.homeTitle(locale),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search),
              label: Text(locale == 'ru' ? 'Поиск клиентов' : 'Scan Clients'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final locale = settings.locale.languageCode;

    final List<Color> availableColors = [
      Colors.deepPurple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizationsStub.settingsTitle(locale)),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: AppLocalizationsStub.interfaceSection(locale)),
          ListTile(
            title: Text(AppLocalizationsStub.themeModeLabel(locale)),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (Set<ThemeMode> selection) {
                notifier.setThemeMode(selection.first);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizationsStub.colorSchemeLabel(locale), 
                     style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: availableColors.map((color) {
                    final isSelected = settings.seedColor == color;
                    return GestureDetector(
                      onTap: () => notifier.setSeedColor(color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected 
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : null,
                          boxShadow: isSelected ? [
                            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)
                          ] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(title: AppLocalizationsStub.languageSection(locale)),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(locale == 'ru' ? 'Русский' : 'Russian'),
            trailing: locale == 'ru' ? const Icon(Icons.check) : null,
            onTap: () => notifier.setLocale(const Locale('ru')),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(locale == 'ru' ? 'Английский' : 'English'),
            trailing: locale == 'en' ? const Icon(Icons.check) : null,
            onTap: () => notifier.setLocale(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
