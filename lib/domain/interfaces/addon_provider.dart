import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

abstract class IAddonProvider {
  String get providerName;

  bool get supportsDiscoveryFeed => false;

  /// Поиск аддонов по запросу и версии игры
  Future<List<AddonItem>> search(String query, String gameVersion);

  /// Получение популярных аддонов для версии игры
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
  }) async {
    return const <AddonItem>[];
  }

  /// Получение прямой ссылки на .zip файл и имени файла
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion,
  );
}
