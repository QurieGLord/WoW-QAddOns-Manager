import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

abstract class IAddonProvider {
  /// Поиск аддонов по запросу и версии игры
  Future<List<AddonItem>> search(String query, String gameVersion);

  /// Получение прямой ссылки на .zip файл и имени файла
  Future<({String url, String fileName})?> getDownloadUrl(AddonItem item, String gameVersion);
}
