import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_client.dart';

class CurseForgeProvider implements IAddonProvider {
  final CurseForgeClient _client;

  CurseForgeProvider(this._client);

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    // Передаем версию игры для жесткой фильтрации на уровне API CurseForge
    final mods = await _client.searchMods(query, gameVersion: gameVersion);
    return mods.map((mod) => AddonItem(
      id: 'cf-${mod.id}',
      name: mod.name,
      summary: mod.summary,
      author: mod.primaryAuthor,
      thumbnailUrl: mod.logo?.thumbnailUrl,
      providerName: 'CurseForge',
      originalId: mod.id,
      version: mod.latestVersion,
    )).toList();
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(AddonItem item, String gameVersion) async {
    final file = await _client.getLatestFileForVersion(item.originalId as int, gameVersion);
    if (file != null && file.downloadUrl != null) {
      return (url: file.downloadUrl!, fileName: file.fileName);
    }
    return null;
  }
}
