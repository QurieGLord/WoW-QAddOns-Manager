import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_mod.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';

class CurseForgeClient {
  final Dio _dio;

  CurseForgeClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.curseforge.com',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Accept': 'application/json',
              'x-api-key': dotenv.env['CURSEFORGE_API_KEY'] ?? '',
            },
          ),
        );

  /// Поиск аддонов с жесткой фильтрацией по версии игры
  Future<List<CfMod>> searchMods(String query, {String? gameVersion}) async {
    if (query.isEmpty) return [];
    try {
      final queryParams = {
        'gameId': '1', // World of Warcraft
        'searchFilter': query,
        'sortField': '2', // По популярности
        'sortOrder': 'desc',
        'pageSize': '20',
      };

      // Если указана версия (например, 3.3.5), CurseForge API отсечет всё лишнее
      if (gameVersion != null && gameVersion.isNotEmpty) {
        queryParams['gameVersion'] = gameVersion;
      }

      final response = await _dio.get(
        '/v1/mods/search',
        queryParameters: queryParams,
      );

      final List data = response.data['data'];
      return data.map((json) => CfMod.fromJson(json)).toList();
    } catch (e) {
      debugPrint('CurseForge Search Error: $e');
      return [];
    }
  }

  /// Получение файла (Force Install / Deep Harvest)
  Future<CfFile?> getLatestFileForVersion(int modId, String gameVersion) async {
    try {
      final isLegacy = !gameVersion.startsWith('10.') && !gameVersion.startsWith('11.');
      
      // 1. Попытка через стандартный фильтр
      var files = await _fetchFiles(modId, gameVersion);
      if (files.isEmpty && isLegacy) {
        final majorMinor = _getMajorMinor(gameVersion);
        if (majorMinor != gameVersion) {
          files = await _fetchFiles(modId, majorMinor);
        }
      }

      if (files.isNotEmpty) {
        files.sort((a, b) => b.id.compareTo(a.id));
        // Ищем первый файл с валидной ссылкой
        for (var f in files) {
          final url = f.downloadUrl;
          if (url != null && url.isNotEmpty) {
            if (kDebugMode) debugPrint('CurseForge Match: $url');
            return f;
          }
        }
      }

      // 2. DEEP HARVEST: Брутфорс по 200 последним файлам
      final response = await _dio.get(
        '/v1/mods/$modId/files',
        queryParameters: {'pageSize': '200'},
      );
      final List data = response.data['data'];
      final allFiles = data.map((json) => CfFile.fromJson(json)).toList();
      allFiles.sort((a, b) => b.id.compareTo(a.id));

      if (allFiles.isEmpty) return null;

      final gv = gameVersion.toLowerCase();
      final isWotlk = gv.startsWith('3.');

      for (var f in allFiles) {
        final url = f.downloadUrl ?? ''; // Безопасный маппинг
        if (url.isEmpty) continue;

        final fileName = f.fileName.toLowerCase();
        final versions = f.gameVersions.map((v) => v.toLowerCase()).toList();

        // БЕЗУСЛОВНЫЙ ЗАХВАТ: Если файл относится к нашей эпохе - берем его!
        if (isWotlk && (versions.contains('wow_classic_wotlk') || versions.contains('wotlk') || fileName.contains('3.3.5'))) {
          if (kDebugMode) debugPrint('CurseForge Unconditional Harvest: $url');
          return f;
        }
        
        if (versions.any((v) => v.contains(gv) || v.contains('classic'))) {
          if (kDebugMode) debugPrint('CurseForge Version/Classic Match: $url');
          return f;
        }
      }

      // 3. FALLBACK: Если это Legacy и мы ничего не нашли по тегам - берем самый свежий живой файл
      if (isLegacy) {
        final fallback = allFiles.firstWhere((f) => (f.downloadUrl ?? '').isNotEmpty, orElse: () => allFiles.first);
        if (kDebugMode) debugPrint('CurseForge Forced Fallback: ${fallback.downloadUrl}');
        return fallback;
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('CurseForge Deep Harvest Error: $e');
      return null;
    }
  }

  Future<List<CfFile>> _fetchFiles(int modId, String version) async {
    final response = await _dio.get(
      '/v1/mods/$modId/files',
      queryParameters: {'gameVersion': version},
    );
    final List data = response.data['data'];
    return data.map((json) => CfFile.fromJson(json)).toList();
  }

  /// Помощник для извлечения Major.Minor версии (3.3.5 -> 3.3)
  String _getMajorMinor(String version) {
    final parts = version.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return version;
  }
}
