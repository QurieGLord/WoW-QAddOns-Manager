import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/addon_resolution_classification.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/data/elvui_manifest_repository.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/domain/elvui_manifest_entry.dart';

class ElvUiResolutionResult {
  final AddonResolutionClassification classification;
  final ElvUiManifestEntry? entry;
  final String clientVersion;
  final String flavor;

  const ElvUiResolutionResult({
    required this.classification,
    required this.entry,
    required this.clientVersion,
    required this.flavor,
  });

  bool get isVerifiedMatch => classification.isVerifiedMatch && entry != null;
}

class ElvUiResolverService {
  static const String providerName = 'ElvUI';
  static const String addonId = 'elvui';
  static const Set<String> _supportedQuerySuffixTokens = <String>{
    'retail',
    'classic',
    'era',
    'vanilla',
    'sod',
    'season',
    'discovery',
    'bc',
    'tbc',
    'wrath',
    'wotlk',
    'cata',
    'cataclysm',
    'mop',
    'pandaria',
    'bfa',
    'shadowlands',
    'dragonflight',
    'war',
    'within',
    'tww',
    'midnight',
  };

  final ElvUiManifestRepository _manifestRepository;

  const ElvUiResolverService(this._manifestRepository);

  bool isElvUiQuery(String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return false;
    }

    var startIndex = 0;
    if (tokens.first == addonId) {
      startIndex = 1;
    } else if (tokens.length >= 2 && tokens[0] == 'elv' && tokens[1] == 'ui') {
      startIndex = 2;
    } else {
      return false;
    }

    if (startIndex >= tokens.length) {
      return true;
    }

    for (final token in tokens.skip(startIndex)) {
      if (_supportedQuerySuffixTokens.contains(token) ||
          RegExp(r'^\d+(?:\.\d+)*$').hasMatch(token)) {
        continue;
      }
      return false;
    }

    return true;
  }

  bool isManifestBackedItem(AddonItem item) {
    return item.providerName == providerName &&
        item.originalId.toString().toLowerCase() == addonId;
  }

  Future<ElvUiResolutionResult> resolveForClient(
    String clientVersion, {
    ClientType? clientType,
  }) async {
    final normalizedVersion = _normalizeComparableVersion(clientVersion);
    final flavor = _resolveFlavor(clientVersion, clientType: clientType);
    final family = WowVersionProfile.parse(clientVersion).family.name;
    final entries = await _manifestRepository.loadEntries();

    final matches =
        entries
            .where(
              (entry) => _matchesEntry(
                entry,
                normalizedVersion,
                flavor: flavor,
                family: family,
              ),
            )
            .where(
              (entry) =>
                  !entry.classification.isVerifiedMatch ||
                  entry.hasPackagePayload,
            )
            .toList()
          ..sort(
            (a, b) => _scoreEntry(
              b,
              normalizedVersion,
            ).compareTo(_scoreEntry(a, normalizedVersion)),
          );

    if (matches.isNotEmpty) {
      final entry = matches.first;
      return ElvUiResolutionResult(
        classification: entry.classification,
        entry: entry,
        clientVersion: normalizedVersion,
        flavor: flavor,
      );
    }

    return ElvUiResolutionResult(
      classification: AddonResolutionClassification.notVerified,
      entry: null,
      clientVersion: normalizedVersion,
      flavor: flavor,
    );
  }

  Future<AddonItem> buildSearchItem(
    String clientVersion, {
    ClientType? clientType,
  }) async {
    final resolution = await resolveForClient(
      clientVersion,
      clientType: clientType,
    );
    return _buildAddonItem(resolution);
  }

  Future<AddonItem?> verifyCandidate(AddonItem item, String gameVersion) async {
    final resolution = await resolveForClient(gameVersion);
    return _buildAddonItem(resolution);
  }

  Future<({String url, String fileName})?> getDownloadInfo(
    AddonItem item,
    String gameVersion,
  ) async {
    final resolved = await verifyCandidate(item, gameVersion);
    if (resolved == null || !resolved.hasVerifiedPayload) {
      return null;
    }

    return (
      url: resolved.verifiedDownloadUrl!,
      fileName: resolved.verifiedFileName!,
    );
  }

  AddonItem _buildAddonItem(ElvUiResolutionResult resolution) {
    final entry = resolution.entry;
    final version = entry?.packageVersion.trim() ?? '';
    final fileName = entry == null || !resolution.classification.isVerifiedMatch
        ? null
        : _deriveFileName(entry);

    return AddonItem(
      id: 'elvui-${resolution.classification.name}',
      name: entry?.name.isNotEmpty == true ? entry!.name : 'ElvUI',
      summary: entry?.summary.isNotEmpty == true
          ? entry!.summary
          : entry?.notes ?? '',
      author: entry?.author.isNotEmpty == true ? entry!.author : null,
      thumbnailUrl: entry?.thumbnailUrl.isNotEmpty == true
          ? entry!.thumbnailUrl
          : null,
      screenshotUrls: entry?.screenshotUrls ?? const <String>[],
      providerName: providerName,
      originalId: addonId,
      sourceSlug: addonId,
      identityHints: <String>[
        addonId,
        if (entry != null) entry.id,
        if (entry != null && entry.flavor.isNotEmpty) entry.flavor,
        if (entry != null && entry.clientFamily.isNotEmpty) entry.clientFamily,
        resolution.flavor,
      ],
      version: version.isNotEmpty ? version : 'N/A',
      verifiedDownloadUrl: resolution.classification.isVerifiedMatch
          ? entry?.packageUrl
          : null,
      verifiedFileName: fileName,
      resolutionClassification: resolution.classification,
    );
  }

  String _deriveFileName(ElvUiManifestEntry entry) {
    final packageUrl = entry.packageUrl.trim();
    final uri = Uri.tryParse(packageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(uri!.pathSegments.last)
        : '';
    if (lastSegment.toLowerCase().endsWith('.zip')) {
      return lastSegment;
    }

    final version = entry.packageVersion.trim();
    final flavor = entry.flavor.trim();
    final flavorSuffix = flavor.isEmpty ? '' : '-$flavor';
    final safeVersion = version.isEmpty ? 'bundle' : version;
    return '${p.basenameWithoutExtension(addonId)}$flavorSuffix-$safeVersion.zip';
  }

  bool _matchesEntry(
    ElvUiManifestEntry entry,
    String clientVersion, {
    required String flavor,
    required String family,
  }) {
    if (entry.flavor.trim().isNotEmpty &&
        entry.flavor.trim().toLowerCase() != flavor) {
      return false;
    }

    final clientFamily = entry.clientFamily.trim().toLowerCase();
    if (clientFamily.isNotEmpty &&
        clientFamily != family.toLowerCase() &&
        clientFamily != flavor) {
      return false;
    }

    if (!_isVersionInRange(
      clientVersion,
      minVersion: entry.clientVersionMin,
      maxVersion: entry.clientVersionMax,
    )) {
      return false;
    }

    return true;
  }

  int _scoreEntry(ElvUiManifestEntry entry, String clientVersion) {
    final exactScore =
        entry.classification == AddonResolutionClassification.exact
        ? 1000
        : entry.classification == AddonResolutionClassification.branchCompatible
        ? 800
        : 200;
    final rangeSpan = _rangeSpan(
      entry.clientVersionMin,
      entry.clientVersionMax,
    );
    final distance = _versionDistance(
      clientVersion,
      entry.clientVersionMin.isEmpty
          ? entry.clientVersionMax
          : entry.clientVersionMin,
    );

    return exactScore - rangeSpan - distance;
  }

  bool _isVersionInRange(
    String version, {
    required String minVersion,
    required String maxVersion,
  }) {
    if (minVersion.trim().isNotEmpty &&
        _compareVersions(version, minVersion) < 0) {
      return false;
    }

    if (maxVersion.trim().isNotEmpty &&
        _compareVersions(version, maxVersion) > 0) {
      return false;
    }

    return true;
  }

  int _rangeSpan(String minVersion, String maxVersion) {
    if (minVersion.trim().isEmpty || maxVersion.trim().isEmpty) {
      return 500;
    }

    return _versionDistance(maxVersion, minVersion);
  }

  int _versionDistance(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = max(leftParts.length, rightParts.length);
    var score = 0;
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      score += (leftValue - rightValue).abs() * (length - index) * 10;
    }
    return score;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = max(leftParts.length, rightParts.length);
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  List<int> _versionParts(String version) {
    return RegExp(r'\d+')
        .allMatches(version)
        .map((match) => int.tryParse(match.group(0)!) ?? 0)
        .toList(growable: false);
  }

  String _resolveFlavor(String clientVersion, {ClientType? clientType}) {
    final profile = WowVersionProfile.parse(clientVersion);
    if (clientType == ClientType.retail ||
        profile.isRetailEra ||
        (profile.major != null && profile.major! >= 8)) {
      return 'retail';
    }

    return switch (profile.family) {
      WowVersionFamily.vanilla => 'vanilla',
      WowVersionFamily.burningCrusade => 'burningCrusade',
      WowVersionFamily.wrath => 'wrath',
      WowVersionFamily.cataclysm => 'cataclysm',
      WowVersionFamily.mistsOfPandaria => 'mistsOfPandaria',
      WowVersionFamily.warlordsOfDraenor => 'warlordsOfDraenor',
      WowVersionFamily.legion => 'legion',
      WowVersionFamily.battleForAzeroth => 'retail',
      WowVersionFamily.shadowlands => 'retail',
      WowVersionFamily.dragonflight => 'retail',
      WowVersionFamily.warWithin => 'retail',
      WowVersionFamily.unknown =>
        clientType == ClientType.classic
            ? 'classic'
            : clientType?.name ?? 'unknown',
    };
  }

  String _normalizeComparableVersion(String version) {
    final profile = WowVersionProfile.parse(version);
    if (profile.exactVersion.trim().isNotEmpty &&
        profile.exactVersion.toLowerCase() != 'unknown') {
      return profile.exactVersion;
    }
    return version.trim();
  }
}
