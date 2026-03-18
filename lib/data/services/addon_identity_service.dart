import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonInstalledMatch {
  final bool isInstalled;
  final bool isStrongMatch;
  final String? matchedGroupId;
  final String? matchedGroupName;
  final List<String> signals;

  const AddonInstalledMatch({
    required this.isInstalled,
    required this.isStrongMatch,
    this.matchedGroupId,
    this.matchedGroupName,
    this.signals = const <String>[],
  });

  static const AddonInstalledMatch none = AddonInstalledMatch(
    isInstalled: false,
    isStrongMatch: false,
  );
}

class AddonIdentityService {
  AddonInstalledMatch matchInstalledAddon(
    AddonItem addon,
    Iterable<InstalledAddonGroup> installedGroups,
  ) {
    final itemIdentity = _buildItemIdentity(addon);
    _MatchCandidate? bestCandidate;

    for (final group in installedGroups) {
      final groupIdentity = _buildGroupIdentity(group);
      final candidate = _evaluateMatch(itemIdentity, groupIdentity);
      if (!candidate.match.isInstalled) {
        continue;
      }

      if (bestCandidate == null || candidate.score > bestCandidate.score) {
        bestCandidate = candidate;
      }
    }

    return bestCandidate?.match ?? AddonInstalledMatch.none;
  }

  _MatchCandidate _evaluateMatch(
    _ItemIdentity item,
    _GroupIdentity group,
  ) {
    final strongSignals = <String>[];
    final mediumSignals = <String>{};

    if (item.sourceKey != null &&
        group.sourceKey != null &&
        item.sourceKey == group.sourceKey) {
      strongSignals.add('source');
    }

    final nameMatch = _hasMeaningfulOverlap(item.baseKeys, group.titleKeys);
    if (nameMatch) {
      mediumSignals.add('name');
    }

    final folderMatch = _hasMeaningfulOverlap(item.anchorKeys, group.folderKeys);
    if (folderMatch) {
      mediumSignals.add('folder');
    }

    if (item.sourceSlugKey != null &&
        (group.folderKeys.contains(item.sourceSlugKey) ||
            group.titleKeys.contains(item.sourceSlugKey))) {
      mediumSignals.add('slug');
    }

    final multiFolderCoverage = _countMeaningfulOverlap(
          item.anchorKeys,
          group.folderKeys,
        ) >=
        2;
    if (multiFolderCoverage) {
      strongSignals.add('multi-folder');
    }

    final isInstalled =
        strongSignals.isNotEmpty || mediumSignals.length >= 2;
    final score = strongSignals.length * 100 + mediumSignals.length * 25;

    return _MatchCandidate(
      score: score,
      match: AddonInstalledMatch(
        isInstalled: isInstalled,
        isStrongMatch: strongSignals.isNotEmpty,
        matchedGroupId: isInstalled ? group.group.id : null,
        matchedGroupName: isInstalled ? group.group.displayName : null,
        signals: <String>[...strongSignals, ...mediumSignals],
      ),
    );
  }

  _ItemIdentity _buildItemIdentity(AddonItem addon) {
    final rawHints = <String>{
      addon.name,
      if (addon.sourceSlug != null) addon.sourceSlug!,
      ...addon.identityHints,
      addon.originalId.toString(),
      _extractLastPathSegment(addon.originalId.toString()),
    }..removeWhere((value) => value.trim().isEmpty);

    final titleKeys = _buildKeySet(rawHints, useBaseForm: true);
    final anchorKeys = <String>{
      ..._buildKeySet(rawHints, useBaseForm: false),
      ...titleKeys,
    };

    return _ItemIdentity(
      sourceKey: _buildSourceKey(addon.providerName, addon.originalId.toString()),
      sourceSlugKey: _nullableCompactKey(
        addon.sourceSlug ?? _extractLastPathSegment(addon.originalId.toString()),
      ),
      baseKeys: titleKeys,
      anchorKeys: anchorKeys,
    );
  }

  _GroupIdentity _buildGroupIdentity(InstalledAddonGroup group) {
    final rawTitles = <String>{
      group.displayName,
      ...group.folderDetails.map((folder) => folder.title),
      ...group.folderDetails.map((folder) => folder.displayName),
    }..removeWhere((value) => value.trim().isEmpty);

    final rawFolders = <String>{
      ...group.installedFolders,
      ...group.folderDetails.map((folder) => folder.folderName),
      ...group.folderDetails.expand((folder) => folder.tocNames),
    }..removeWhere((value) => value.trim().isEmpty);

    return _GroupIdentity(
      group: group,
      sourceKey: _buildGroupSourceKey(group),
      titleKeys: _buildKeySet(rawTitles, useBaseForm: true),
      folderKeys: _buildKeySet(rawFolders, useBaseForm: false),
    );
  }

  Set<String> _buildKeySet(
    Iterable<String> values, {
    required bool useBaseForm,
  }) {
    final keys = <String>{};

    for (final value in values) {
      final normalized = useBaseForm ? _extractBasePhrase(value) : _normalizePhrase(value);
      final compact = _compactKey(normalized);
      if (_isMeaningfulKey(compact)) {
        keys.add(compact);
      }
    }

    return keys;
  }

  bool _hasMeaningfulOverlap(Set<String> first, Set<String> second) {
    return _countMeaningfulOverlap(first, second) > 0;
  }

  int _countMeaningfulOverlap(Set<String> first, Set<String> second) {
    var count = 0;
    for (final value in first) {
      if (second.contains(value) && _isMeaningfulKey(value)) {
        count++;
      }
    }
    return count;
  }

  bool _isMeaningfulKey(String value) {
    if (value.length < 3) {
      return false;
    }

    if (RegExp(r'^\d+$').hasMatch(value)) {
      return false;
    }

    return !_weakIdentityKeys.contains(value);
  }

  String? _buildSourceKey(String providerName, String originalId) {
    final normalizedProvider = providerName.trim().toLowerCase();
    final normalizedId = originalId.trim().toLowerCase();
    if (normalizedProvider.isEmpty || normalizedId.isEmpty) {
      return null;
    }

    return '$normalizedProvider:$normalizedId';
  }

  String? _buildGroupSourceKey(InstalledAddonGroup group) {
    if (group.providerName != null && group.originalId != null) {
      return _buildSourceKey(group.providerName!, group.originalId!);
    }

    final separatorIndex = group.id.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex >= group.id.length - 1) {
      return null;
    }

    final provider = group.id.substring(0, separatorIndex);
    final originalId = group.id.substring(separatorIndex + 1);
    return _buildSourceKey(provider, originalId);
  }

  String _normalizePhrase(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\|c[0-9a-fA-F]{8}'), '')
        .replaceAll('|r', '')
        .replaceAll(RegExp(r'[_/\\\\:+-]+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9!+\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractBasePhrase(String value) {
    var candidate = value.trim();
    final bangIndex = candidate.indexOf('!');
    if (bangIndex > 0 && bangIndex < candidate.length - 1) {
      candidate = candidate.substring(0, bangIndex);
    }

    candidate = candidate
        .replaceAll(RegExp(r'\[[^\]]+\]'), ' ')
        .replaceAll(RegExp(r'\([^\)]+\)'), ' ');

    final words = _normalizePhrase(candidate)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: true);

    while (words.isNotEmpty && _isRemovableSuffix(words.last)) {
      words.removeLast();
    }

    return words.join(' ').trim();
  }

  bool _isRemovableSuffix(String token) {
    if (_versionSuffixPattern.hasMatch(token)) {
      return true;
    }

    return _removableSuffixes.contains(token);
  }

  String _compactKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _nullableCompactKey(String value) {
    final compact = _compactKey(value);
    return compact.isEmpty ? null : compact;
  }

  String _extractLastPathSegment(String value) {
    final segments = value
        .split(RegExp(r'[\\/]+'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? value : segments.last;
  }

  static final RegExp _versionSuffixPattern = RegExp(
    r'^\d+(?:\.\d+)+(?:[a-z])?$',
  );

  static const Set<String> _removableSuffixes = <String>{
    'classic',
    'retail',
    'ptr',
    'beta',
    'era',
    'sod',
    'vanilla',
    'bc',
    'tbc',
    'wotlk',
    'wrath',
    'cata',
    'mop',
    'wod',
    'legion',
    'bfa',
    'shadowlands',
    'dragonflight',
    'tww',
    'war',
    'within',
    'damage',
    'meter',
    'meters',
    'bossmods',
    'bossmod',
    'options',
    'config',
  };

  static const Set<String> _weakIdentityKeys = <String>{
    'wow',
    'worldofwarcraft',
    'addon',
    'addons',
    'classic',
    'retail',
    'ptr',
    'beta',
    'ui',
  };
}

class _ItemIdentity {
  final String? sourceKey;
  final String? sourceSlugKey;
  final Set<String> baseKeys;
  final Set<String> anchorKeys;

  const _ItemIdentity({
    required this.sourceKey,
    required this.sourceSlugKey,
    required this.baseKeys,
    required this.anchorKeys,
  });
}

class _GroupIdentity {
  final InstalledAddonGroup group;
  final String? sourceKey;
  final Set<String> titleKeys;
  final Set<String> folderKeys;

  const _GroupIdentity({
    required this.group,
    required this.sourceKey,
    required this.titleKeys,
    required this.folderKeys,
  });
}

class _MatchCandidate {
  final int score;
  final AddonInstalledMatch match;

  const _MatchCandidate({
    required this.score,
    required this.match,
  });
}
