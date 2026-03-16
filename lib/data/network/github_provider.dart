import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class GitHubProvider implements IAddonProvider {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.github.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/vnd.github.v3+json',
    },
  ));

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    if (query.isEmpty) return [];
    try {
      // 1. Пытаемся сделать точный запрос (версия + эпоха + язык)
      String q = '$query "$gameVersion" language:Lua';
      if (gameVersion.startsWith('3.')) q += ' wotlk';
      if (gameVersion.startsWith('1.')) q += ' classic era';
      
      var items = await _performSearch(q);

      // 2. FALLBACK: Если ничего не нашли, пробуем упрощенный поиск
      if (items.isEmpty) {
        if (kDebugMode) debugPrint('GitHub: No results for strict query, trying fallback...');
        items = await _performSearch('$query "$gameVersion"');
      }

      final List<AddonItem> results = [];
      for (var item in items) {
        final name = (item['name'] as String).toLowerCase();
        final description = (item['description'] ?? '').toString().toLowerCase();
        
        final bool isPack = name.contains('pack') || 
                           name.contains('collection') || 
                           name.contains('bundle') ||
                           description.contains('pack') ||
                           description.contains('collection');
        
        if (isPack) continue;

        results.add(AddonItem(
          id: 'gh-${item['id']}',
          name: item['name'],
          summary: item['description'] ?? 'No description available',
          author: item['owner']['login'],
          thumbnailUrl: item['owner']['avatar_url'],
          providerName: 'GitHub',
          originalId: item['full_name'],
          version: 'latest',
        ));
      }
      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('GitHub Search Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> _performSearch(String q) async {
    try {
      final response = await _dio.get(
        '/search/repositories',
        queryParameters: {
          'q': q,
          'sort': 'stars',
          'order': 'desc',
          'per_page': 10,
        },
      );
      return response.data['items'] ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(AddonItem item, String gameVersion) async {
    try {
      // 1. Попытка получить последний релиз
      final response = await _dio.get('/repos/${item.originalId}/releases/latest');
      final List assets = response.data['assets'];
      
      final asset = assets.firstWhere(
        (a) => (a['name'] as String).toLowerCase().endsWith('.zip'),
        orElse: () => null,
      );

      if (asset != null) {
        final url = asset['browser_download_url'] as String;
        if (kDebugMode) debugPrint('GitHub Release URL: $url');
        return (url: url, fileName: asset['name'] as String);
      }
    } catch (e) {
      // 2. FALLBACK: Если релизов нет (404) или нет ZIP в активах - качаем архив ветки master/main
      if (kDebugMode) debugPrint('GitHub Release failed, trying branch fallback for ${item.originalId}');
      
      // Формируем ссылки-кандидаты
      final repo = item.originalId; // author/repo
      final masterUrl = 'https://github.com/$repo/archive/refs/heads/master.zip';
      
      // Мы возвращаем master.zip как наиболее вероятный вариант для старых аддонов.
      // Алгоритм Safe Extraction справится с папкой внутри архива.
      return (url: masterUrl, fileName: '${repo.split('/').last}-master.zip');
    }
    return null;
  }
}
