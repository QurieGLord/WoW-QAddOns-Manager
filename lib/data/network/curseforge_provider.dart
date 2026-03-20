import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/data/network/curseforge_client.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_mod.dart';

class CurseForgeProvider extends IAddonProvider {
  static const String staticProviderName = 'CurseForge';

  final CurseForgeClient _client;

  CurseForgeProvider(this._client);

  @override
  String get providerName => staticProviderName;

  @override
  bool get supportsDiscoveryFeed => true;

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    return searchWithContext(query, gameVersion);
  }

  Future<List<AddonItem>> searchWithContext(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    final profile = WowVersionProfile.parse(gameVersion);
    final mods = await _client.searchMods(
      query,
      gameVersion: gameVersion,
      requestContext: requestContext,
    );
    final rankedCandidates =
        mods
            .map(
              (mod) => (
                mod: mod,
                previewFile: _client.getPreviewFileForVersion(mod, gameVersion),
                previewEvidenceScore: _client.getPreviewEvidenceScore(
                  mod,
                  gameVersion,
                ),
                metadataScore: _client.getMetadataCompatibilityScore(
                  mod,
                  gameVersion,
                ),
                queryScore: _scoreQueryMatch(mod, query),
              ),
            )
            .where(
              (candidate) =>
                  candidate.previewEvidenceScore > 0 ||
                  candidate.metadataScore > 0,
            )
            .where(
              (candidate) => !_hasConflictingMetadata(
                candidate.mod,
                profile,
                previewFile: candidate.previewFile,
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                (b.previewEvidenceScore * 2 + b.metadataScore + b.queryScore)
                    .compareTo(
                      a.previewEvidenceScore * 2 +
                          a.metadataScore +
                          a.queryScore,
                    ),
          );

    return rankedCandidates
        .take(40)
        .map(
          (candidate) => _buildAddonItem(
            candidate.mod,
            profile,
            previewFile: candidate.previewFile,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
  }) async {
    return fetchPopularAddonsWithContext(gameVersion, limit: limit);
  }

  Future<List<AddonItem>> fetchPopularAddonsWithContext(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  }) async {
    final profile = WowVersionProfile.parse(gameVersion);
    final mods = await _client.fetchPopularMods(
      gameVersion,
      limit: limit,
      requestContext: requestContext,
    );
    final rankedCandidates =
        mods
            .map(
              (mod) => (
                mod: mod,
                previewFile: _client.getPreviewFileForVersion(mod, gameVersion),
                previewEvidenceScore: _client.getPreviewEvidenceScore(
                  mod,
                  gameVersion,
                ),
                metadataScore: _client.getMetadataCompatibilityScore(
                  mod,
                  gameVersion,
                ),
              ),
            )
            .where(
              (candidate) =>
                  candidate.previewEvidenceScore > 0 ||
                  candidate.metadataScore > 0,
            )
            .where(
              (candidate) => !_hasConflictingMetadata(
                candidate.mod,
                profile,
                previewFile: candidate.previewFile,
              ),
            )
            .toList()
          ..sort(
            (a, b) => (b.previewEvidenceScore * 2 + b.metadataScore).compareTo(
              a.previewEvidenceScore * 2 + a.metadataScore,
            ),
          );

    return rankedCandidates
        .take(limit)
        .map(
          (candidate) => _buildAddonItem(
            candidate.mod,
            profile,
            previewFile: candidate.previewFile,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(
    AddonItem item,
    String gameVersion,
  ) async {
    return getDownloadUrlWithContext(item, gameVersion);
  }

  Future<({String url, String fileName})?> getDownloadUrlWithContext(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    if (item.hasVerifiedPayload) {
      return (url: item.verifiedDownloadUrl!, fileName: item.verifiedFileName!);
    }

    final file = await _client.getLatestFileForVersion(
      item.originalId as int,
      gameVersion,
      requestContext: requestContext,
    );
    if (file != null &&
        file.downloadUrl != null &&
        file.downloadUrl!.isNotEmpty) {
      return (url: file.downloadUrl!, fileName: file.fileName);
    }
    return null;
  }

  @override
  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion) async {
    return verifyCandidateWithContext(item, gameVersion);
  }

  Future<AddonItem?> verifyCandidateWithContext(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    if (item.hasVerifiedPayload) {
      return item;
    }

    final profile = WowVersionProfile.parse(gameVersion);
    final file = await _client.getLatestFileForVersion(
      item.originalId as int,
      gameVersion,
      requestContext: requestContext,
    );
    if (file == null ||
        file.downloadUrl == null ||
        file.downloadUrl!.trim().isEmpty) {
      return null;
    }

    return item.copyWith(
      name: _resolveVerifiedDisplayName(item, file, profile),
      version: _resolveMatchedVersionFromFile(file, profile),
      verifiedDownloadUrl: file.downloadUrl,
      verifiedFileName: file.fileName,
      identityHints: <String>[
        ...item.identityHints,
        if (file.displayName != null) file.displayName!,
        file.fileName,
      ],
    );
  }

  AddonItem _buildAddonItem(
    CfMod mod,
    WowVersionProfile profile, {
    CfFile? previewFile,
  }) {
    return AddonItem(
      id: 'cf-${mod.id}',
      name: _resolveDisplayName(mod, previewFile, profile),
      summary: mod.summary,
      author: mod.primaryAuthor,
      thumbnailUrl: mod.logo?.thumbnailUrl,
      providerName: providerName,
      originalId: mod.id,
      identityHints: <String>[
        mod.name,
        if (previewFile?.displayName != null) previewFile!.displayName!,
        if (previewFile != null) previewFile.fileName,
        if (previewFile != null) _deriveNameFromFileName(previewFile.fileName),
      ],
      version: _resolveMatchedVersion(previewFile, mod, profile),
    );
  }

  int _scoreQueryMatch(CfMod mod, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final name = mod.name.toLowerCase();
    final summary = mod.summary.toLowerCase();
    if (name == normalizedQuery) {
      return 120;
    }
    if (name.contains(normalizedQuery)) {
      return 80;
    }
    if (summary.contains(normalizedQuery)) {
      return 40;
    }
    return 10;
  }

  bool _hasConflictingMetadata(
    CfMod mod,
    WowVersionProfile profile, {
    CfFile? previewFile,
  }) {
    if (previewFile != null &&
        profile.numericCompatibilityScore(<String>[
              previewFile.fileName,
              if (previewFile.displayName != null) previewFile.displayName!,
              ...previewFile.gameVersions,
            ]) >
            0) {
      return false;
    }

    final metadataHaystack = '${mod.name} ${mod.summary}'.toLowerCase();
    return profile.containsConflictingVersionMarker(metadataHaystack);
  }

  String _resolveDisplayName(
    CfMod mod,
    CfFile? matchedFile,
    WowVersionProfile profile,
  ) {
    final normalizedModName = mod.name.trim();
    if (!profile.containsConflictingVersionMarker(
      normalizedModName.toLowerCase(),
    )) {
      return normalizedModName;
    }

    if (matchedFile == null) {
      return normalizedModName.split(' - ').first.trim();
    }

    final derivedName = _deriveNameFromFileName(matchedFile.fileName);
    return derivedName.isEmpty
        ? normalizedModName.split(' - ').first.trim()
        : derivedName;
  }

  String _resolveMatchedVersion(
    CfFile? file,
    CfMod mod,
    WowVersionProfile profile,
  ) {
    if (file == null) {
      final previewVersion = mod.latestFiles
          .expand((candidate) => candidate.gameVersions)
          .firstWhere(
            (version) =>
                profile.numericCompatibilityScore(<String>[version]) > 0,
            orElse: () => '',
          );

      if (previewVersion.isNotEmpty) {
        return previewVersion;
      }

      return profile.majorMinor;
    }

    return _resolveMatchedVersionFromFile(file, profile);
  }

  String _resolveMatchedVersionFromFile(
    CfFile file,
    WowVersionProfile profile,
  ) {
    final compatibleVersions =
        file.gameVersions
            .where(
              (version) =>
                  profile.numericCompatibilityScore(<String>[version]) > 0,
            )
            .toList()
          ..sort((a, b) {
            final scoreComparison = profile
                .numericCompatibilityScore(<String>[b])
                .compareTo(profile.numericCompatibilityScore(<String>[a]));
            if (scoreComparison != 0) {
              return scoreComparison;
            }

            final aProfile = WowVersionProfile.parse(a);
            final bProfile = WowVersionProfile.parse(b);
            final aExact = aProfile.exactVersion == profile.exactVersion
                ? 1
                : 0;
            final bExact = bProfile.exactVersion == profile.exactVersion
                ? 1
                : 0;
            return bExact.compareTo(aExact);
          });

    if (compatibleVersions.isNotEmpty) {
      return compatibleVersions.first;
    }

    if (file.displayName != null &&
        profile.numericCompatibilityScore(<String>[file.displayName!]) > 0) {
      return profile.exactVersion != profile.majorMinor
          ? profile.exactVersion
          : profile.majorMinor;
    }

    if (profile.numericCompatibilityScore(<String>[file.fileName]) > 0) {
      return profile.exactVersion != profile.majorMinor
          ? profile.exactVersion
          : profile.majorMinor;
    }

    return file.gameVersions.isNotEmpty
        ? file.gameVersions.first
        : profile.majorMinor;
  }

  String _resolveVerifiedDisplayName(
    AddonItem item,
    CfFile file,
    WowVersionProfile profile,
  ) {
    if (!profile.containsConflictingVersionMarker(item.name.toLowerCase())) {
      return item.name;
    }

    final derivedName = _deriveNameFromFileName(file.fileName);
    return derivedName.isEmpty ? item.name : derivedName;
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
