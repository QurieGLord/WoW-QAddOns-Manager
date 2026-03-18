import 'package:flutter/foundation.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_provider.dart';
import 'package:wow_qaddons_manager/data/network/github_provider.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class AddonSearchService {
  final List<IAddonProvider> _providers;

  AddonSearchService(this._providers);

  /// Поиск по всем провайдерам параллельно
  Future<List<AddonItem>> searchAll(String query, String gameVersion) async {
    final normalizedQuery = query.trim();
    final normalizedVersion = gameVersion.trim();

    if (normalizedQuery.isEmpty || normalizedVersion.isEmpty) {
      return [];
    }

    final results = await Future.wait(
      _providers.map(
        (provider) => provider
            .search(normalizedQuery, normalizedVersion)
            .catchError((_) => <AddonItem>[]),
      ),
    );

    final merged = <String, AddonItem>{};
    for (final item in results.expand((list) => list)) {
      merged['${item.providerName}:${item.originalId}'] = item;
    }

    return merged.values.toList();
  }

  Future<List<AddonItem>> fetchDiscoveryFeed(
    String gameVersion, {
    int limit = 50,
  }) async {
    final normalizedVersion = gameVersion.trim();
    if (normalizedVersion.isEmpty) {
      return [];
    }

    for (final provider in _providers) {
      if (!provider.supportsDiscoveryFeed) {
        continue;
      }

      final items = await provider.fetchPopularAddons(
        normalizedVersion,
        limit: limit,
      );
      if (items.isNotEmpty) {
        return items;
      }
    }

    return [];
  }

  /// Получение ссылки на скачивание через соответствующего провайдера
  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) async {
    final normalizedVersion = gameVersion.trim();
    if (normalizedVersion.isEmpty) {
      return null;
    }

    try {
      for (final provider in _providers) {
        if (item.providerName == provider.providerName) {
          final info = await provider.getDownloadUrl(item, normalizedVersion);
          if (info != null && info.url.isNotEmpty) {
            return info;
          }
        }
      }

      for (final provider in _providers) {
        if (item.providerName == GitHubProvider.staticProviderName &&
            provider is GitHubProvider) {
          final info = await provider.getDownloadUrl(item, normalizedVersion);
          if (info != null && info.url.isNotEmpty) {
            return info;
          }
        }
        if (item.providerName == CurseForgeProvider.staticProviderName &&
            provider is CurseForgeProvider) {
          final info = await provider.getDownloadUrl(item, normalizedVersion);
          if (info != null && info.url.isNotEmpty) {
            return info;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Search Service Error: $e');
      }
    }

    return null;
  }
}
