import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class WagoProvider implements IAddonProvider {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://addons.wago.io/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      'Referer': 'https://addons.wago.io/',
    },
  ));

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    if (query.isEmpty) return [];
    try {
      String flavor = 'retail';
      if (gameVersion.startsWith('1.') || gameVersion.startsWith('3.')) flavor = 'classic';
      if (gameVersion.startsWith('4.') || gameVersion.startsWith('5.')) flavor = 'classic';

      final response = await _dio.get('/search/addons', queryParameters: {
        'q': query,
        'game': 'wow',
        'flavor': flavor,
      });

      final dynamic data = response.data;
      if (data is String) return []; // Silent error for HTML

      final List? addonsData = (data is Map) ? data['addons'] : (data is List ? data : null);
      if (addonsData == null) return [];

      final List<AddonItem> results = [];
      for (var item in addonsData) {
        if (item is! Map<String, dynamic>) continue;

        results.add(AddonItem(
          id: 'wago-${item['slug'] ?? item['id']}',
          name: item['name'] ?? 'Unknown',
          summary: item['description'] ?? 'No description',
          author: (item['owner'] is Map) ? (item['owner']['username'] ?? 'Unknown') : 'Unknown',
          thumbnailUrl: (item['logo'] is Map) ? item['logo']['url'] : null,
          providerName: 'Wago',
          originalId: item['slug'] ?? item['id'],
          version: item['version'] ?? 'N/A',
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(AddonItem item, String gameVersion) async {
    try {
      final response = await _dio.get('/addons/${item.originalId}');
      if (response.data == null || response.data['stable'] == null) return null;

      final stable = response.data['stable'];
      final String? downloadUrl = stable['downloadUrl'];
      
      if (downloadUrl != null) {
        final fileName = downloadUrl.split('/').last;
        if (kDebugMode) debugPrint('Wago Download URL: $downloadUrl');
        return (url: downloadUrl, fileName: fileName);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
