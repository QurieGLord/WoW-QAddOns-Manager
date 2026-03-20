import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

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

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  AppSettingsNotifier(this._prefs)
    : super(
        AppSettingsState(
          themeMode: ThemeMode
              .values[_prefs.getInt('themeMode') ?? ThemeMode.system.index],
          locale: Locale(_prefs.getString('locale') ?? 'en'),
          seedColor: Color(_prefs.getInt('seedColor') ?? 0xFF6750A4),
        ),
      );

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

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      return AppSettingsNotifier(ref.watch(sharedPrefsProvider));
    });
