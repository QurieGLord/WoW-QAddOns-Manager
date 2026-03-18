import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_client.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_mod.dart';

class CurseForgeProvider implements IAddonProvider {
  static const String staticProviderName = 'CurseForge';

  final CurseForgeClient _client;

  CurseForgeProvider(this._client);

  @override
  String get providerName => staticProviderName;

  @override
  bool get supportsDiscoveryFeed => true;

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    final profile = WowVersionProfile.parse(gameVersion);
    final mods = await _client.searchMods(query, gameVersion: gameVersion);
    final results = <AddonItem>[];

    for (final mod in mods) {
      final matchedFile = await _client.getLatestFileForVersion(
        mod.id,
        gameVersion,
      );
      if (matchedFile == null) {
        continue;
      }

      results.add(
        AddonItem(
          id: 'cf-${mod.id}',
          name: _resolveDisplayName(mod, matchedFile, profile),
          summary: mod.summary,
          author: mod.primaryAuthor,
          thumbnailUrl: mod.logo?.thumbnailUrl,
          providerName: providerName,
          originalId: mod.id,
          version: _resolveMatchedVersion(matchedFile, profile),
        ),
      );

      if (results.length >= 12) {
        break;
      }
    }

    return results;
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
  }) async {
    final profile = WowVersionProfile.parse(gameVersion);
    final mods = await _client.fetchPopularMods(gameVersion, limit: limit);

    final items = await Future.wait(
      mods.take(limit).map((mod) async {
        final matchedFile = await _client.getLatestFileForVersion(
          mod.id,
          gameVersion,
        );
        if (matchedFile == null) {
          return null;
        }

        return AddonItem(
          id: 'cf-${mod.id}',
          name: _resolveDisplayName(mod, matchedFile, profile),
          summary: mod.summary,
          author: mod.primaryAuthor,
          thumbnailUrl: mod.logo?.thumbnailUrl,
          providerName: providerName,
          originalId: mod.id,
          version: _resolveMatchedVersion(matchedFile, profile),
        );
      }),
    );

    return items.whereType<AddonItem>().take(limit).toList(growable: false);
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion,
  ) async {
    final file = await _client.getLatestFileForVersion(
      item.originalId as int,
      gameVersion,
    );
    if (file != null &&
        file.downloadUrl != null &&
        file.downloadUrl!.isNotEmpty) {
      return (url: file.downloadUrl!, fileName: file.fileName);
    }
    return null;
  }

  String _resolveDisplayName(
    CfMod mod,
    CfFile matchedFile,
    WowVersionProfile profile,
  ) {
    final normalizedModName = mod.name.trim();
    if (!profile.containsConflictingVersionMarker(
      normalizedModName.toLowerCase(),
    )) {
      return normalizedModName;
    }

    final derivedName = _deriveNameFromFileName(matchedFile.fileName);
    return derivedName.isEmpty
        ? normalizedModName.split(' - ').first.trim()
        : derivedName;
  }

  String _resolveMatchedVersion(CfFile file, WowVersionProfile profile) {
    for (final version in file.gameVersions) {
      if (version.toLowerCase() == profile.normalizedVersion) {
        return version;
      }
    }

    for (final version in file.gameVersions) {
      if (version.toLowerCase().startsWith(profile.majorMinor)) {
        return version;
      }
    }

    if (file.displayName != null &&
        profile.containsRequestedVersion(file.displayName!)) {
      return profile.majorMinor;
    }

    return file.gameVersions.isNotEmpty
        ? file.gameVersions.first
        : profile.majorMinor;
  }

  String _deriveNameFromFileName(String fileName) {
    var name = fileName.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[_-]v?\d[\w.-]*$'), '');
    name = name.replaceAll(
      RegExp(r'[_-](wrath|bcc|classic|retail)$', caseSensitive: false),
      '',
    );
    name = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return name;
  }
}
