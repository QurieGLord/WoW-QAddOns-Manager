import 'package:flutter/foundation.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/data/network/wago_provider.dart';

class AddonSearchService {
  final List<IAddonProvider> _providers;

  AddonSearchService(this._providers);

  /// Поиск по всем провайдерам параллельно
  Future<List<AddonItem>> searchAll(String query, String gameVersion) async {
    if (query.isEmpty) return [];

    final results = await Future.wait(
      _providers.map((p) => p.search(query, gameVersion).catchError((_) => <AddonItem>[])),
    );

    // Объединяем результаты
    return results.expand((list) => list).toList();
  }

  /// Получение ссылки на скачивание через соответствующего провайдера
  Future<({String url, String fileName})?> getDownloadInfo(AddonItem item, String gameVersion) async {
    try {
      for (final provider in _providers) {
        if (item.providerName == provider.runtimeType.toString().replaceAll('Provider', '')) {
          final info = await provider.getDownloadUrl(item, gameVersion);
          if (info != null && info.url.isNotEmpty) return info;
        }
      }
      
      // Fallback на старую логику
      for (final provider in _providers) {
         if (item.providerName == 'GitHub' && provider is GitHubProvider) {
          final info = await provider.getDownloadUrl(item, gameVersion);
          if (info != null && info.url.isNotEmpty) return info;
        }
        if (item.providerName == 'CurseForge' && provider is CurseForgeProvider) {
          final info = await provider.getDownloadUrl(item, gameVersion);
          if (info != null && info.url.isNotEmpty) return info;
        }
        if (item.providerName == 'Wago' && provider is WagoProvider) {
          final info = await provider.getDownloadUrl(item, gameVersion);
          if (info != null && info.url.isNotEmpty) return info;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Search Service Error: $e');
    }

    return null;
  }
}
