enum WowVersionFamily {
  vanilla,
  burningCrusade,
  wrath,
  cataclysm,
  mistsOfPandaria,
  warlordsOfDraenor,
  legion,
  battleForAzeroth,
  shadowlands,
  dragonflight,
  warWithin,
  unknown,
}

class WowVersionProfile {
  WowVersionProfile._({
    required this.rawVersion,
    required this.normalizedVersion,
    required this.exactVersion,
    required this.majorMinor,
    required this.major,
    required this.minor,
    required this.patch,
    required this.family,
  });

  factory WowVersionProfile.parse(String version) {
    final normalized = version.trim().toLowerCase();
    final components =
        RegExp(r'\d+')
            .allMatches(normalized)
            .map((match) => int.tryParse(match.group(0)!))
            .whereType<int>()
            .toList(growable: false);

    final major = components.isNotEmpty ? components[0] : null;
    final minor = components.length > 1 ? components[1] : null;
    final patch = components.length > 2 ? components[2] : null;
    final exactVersion =
        major != null && minor != null && patch != null
            ? '$major.$minor.$patch'
            : normalized;
    final majorMinor = major != null && minor != null ? '$major.$minor' : normalized;

    return WowVersionProfile._(
      rawVersion: version,
      normalizedVersion: normalized,
      exactVersion: exactVersion,
      majorMinor: majorMinor,
      major: major,
      minor: minor,
      patch: patch,
      family: _detectFamily(normalized, major, minor),
    );
  }

  final String rawVersion;
  final String normalizedVersion;
  final String exactVersion;
  final String majorMinor;
  final int? major;
  final int? minor;
  final int? patch;
  final WowVersionFamily family;

  bool get isEmpty => normalizedVersion.isEmpty;

  bool get hasNumericVersion => major != null && minor != null;

  bool get isRetailEra {
    return switch (family) {
      WowVersionFamily.battleForAzeroth ||
      WowVersionFamily.shadowlands ||
      WowVersionFamily.dragonflight ||
      WowVersionFamily.warWithin => true,
      _ => false,
    };
  }

  List<String> get apiVersionCandidates {
    if (!hasNumericVersion) {
      return const <String>[];
    }

    final candidates = <String>[
      if (_looksLikeVersion(normalizedVersion)) normalizedVersion,
      if (_looksLikeVersion(exactVersion) && exactVersion != normalizedVersion) exactVersion,
      if (_looksLikeVersion(majorMinor) && majorMinor != exactVersion) majorMinor,
    ];

    return candidates.toSet().toList(growable: false);
  }

  List<String> get searchVersionTokens {
    final tokens = <String>[
      ...apiVersionCandidates,
      ...familySearchKeywords,
      if (isRetailEra) 'retail',
    ];

    return tokens.toSet().toList(growable: false);
  }

  List<String> get familySearchKeywords {
    final aliases = _familyAliases[family] ?? const <String>[];
    return aliases.where((alias) => alias.length >= 3).toList(growable: false);
  }

  bool containsRequestedVersion(String text) {
    final haystack = text.toLowerCase();
    for (final token in searchVersionTokens) {
      if (_containsToken(haystack, token)) {
        return true;
      }
    }
    return false;
  }

  bool containsKnownVersionMarker(String text) {
    final haystack = text.toLowerCase();

    if (_containsKnownBranchToken(haystack)) {
      return true;
    }

    for (final aliases in _familyAliases.values) {
      for (final alias in aliases) {
        if (_containsToken(haystack, alias)) {
          return true;
        }
      }
    }

    return _containsToken(haystack, 'retail');
  }

  bool containsConflictingVersionMarker(String text) {
    final haystack = text.toLowerCase();
    if (haystack.trim().isEmpty) {
      return false;
    }

    if (_containsConflictingKnownBranch(haystack)) {
      return true;
    }

    if (_containsConflictingFamilyAlias(haystack)) {
      return true;
    }

    if (!isRetailEra && _containsToken(haystack, 'retail')) {
      return true;
    }

    return false;
  }

  int numericCompatibilityScore(Iterable<String> values) {
    var bestScore = 0;
    for (final value in values) {
      final score = _scoreValue(value);
      if (score > bestScore) {
        bestScore = score;
      }
    }
    return bestScore;
  }

  int _scoreValue(String value) {
    final haystack = value.toLowerCase();
    if (haystack.trim().isEmpty) {
      return 0;
    }

    if (containsConflictingVersionMarker(haystack)) {
      return 0;
    }

    var score = 0;

    if (_looksLikeVersion(exactVersion) &&
        exactVersion != majorMinor &&
        _containsToken(haystack, exactVersion)) {
      score = 240;
    }

    if (_looksLikeVersion(majorMinor) && _containsToken(haystack, majorMinor)) {
      score = score < 200 ? 200 : score;
    }

    if (_containsFamilyAlias(haystack)) {
      score = score < 120 ? 120 : score;
    }

    if (major != null &&
        RegExp(
          '(?<!\\d)${RegExp.escape('$major')}(?:\\.\\d|\\.x|x)(?!\\d)',
          caseSensitive: false,
        ).hasMatch(haystack)) {
      score = score < 40 ? 40 : score;
    }

    if (isRetailEra && _containsToken(haystack, 'retail')) {
      score = score < 20 ? 20 : score;
    }

    return score;
  }

  bool _containsFamilyAlias(String text) {
    for (final alias in _familyAliases[family] ?? const <String>[]) {
      if (_containsToken(text, alias)) {
        return true;
      }
    }
    return false;
  }

  bool _containsConflictingFamilyAlias(String text) {
    for (final entry in _familyAliases.entries) {
      if (entry.key == family) {
        continue;
      }

      for (final alias in entry.value) {
        if (_containsToken(text, alias)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _containsKnownBranchToken(String text) {
    for (final branches in _familyBranches.values) {
      for (final branch in branches) {
        if (_containsToken(text, branch)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _containsConflictingKnownBranch(String text) {
    if (!_looksLikeVersion(majorMinor)) {
      return false;
    }

    for (final branches in _familyBranches.values) {
      for (final branch in branches) {
        if (branch == majorMinor) {
          continue;
        }

        if (_containsToken(text, branch)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _looksLikeVersion(String value) {
    return RegExp(r'^\d+\.\d+(?:\.\d+)?[a-z]?$').hasMatch(value.trim());
  }

  static bool _containsToken(String text, String token) {
    if (token.trim().isEmpty) {
      return false;
    }

    final normalizedToken = token.toLowerCase();
    final pattern =
        RegExp(r'^\d+(?:\.\d+)+[a-z]?$').hasMatch(normalizedToken)
            ? '(?<!\\d)${RegExp.escape(normalizedToken)}(?!\\d)'
            : '(?<![a-z0-9])${RegExp.escape(normalizedToken)}(?![a-z0-9])';

    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  static WowVersionFamily _detectFamily(String normalizedVersion, int? major, int? minor) {
    if (normalizedVersion.isNotEmpty) {
      for (final entry in _familyAliases.entries) {
        for (final alias in entry.value) {
          if (_containsToken(normalizedVersion, alias)) {
            return entry.key;
          }
        }
      }
    }

    final branch = major != null && minor != null ? '$major.$minor' : null;
    if (branch != null) {
      for (final entry in _familyBranches.entries) {
        if (entry.value.contains(branch)) {
          return entry.key;
        }
      }
    }

    return switch (major) {
      1 => WowVersionFamily.vanilla,
      2 => WowVersionFamily.burningCrusade,
      3 => WowVersionFamily.wrath,
      4 => WowVersionFamily.cataclysm,
      5 => WowVersionFamily.mistsOfPandaria,
      6 => WowVersionFamily.warlordsOfDraenor,
      7 => WowVersionFamily.legion,
      8 => WowVersionFamily.battleForAzeroth,
      9 => WowVersionFamily.shadowlands,
      10 => WowVersionFamily.dragonflight,
      11 => WowVersionFamily.warWithin,
      _ => WowVersionFamily.unknown,
    };
  }

  static const Map<WowVersionFamily, List<String>> _familyBranches = {
    WowVersionFamily.vanilla: <String>['1.12', '1.13', '1.14', '1.15'],
    WowVersionFamily.burningCrusade: <String>['2.0', '2.1', '2.2', '2.3', '2.4', '2.5'],
    WowVersionFamily.wrath: <String>['3.0', '3.1', '3.2', '3.3', '3.4'],
    WowVersionFamily.cataclysm: <String>['4.0', '4.1', '4.2', '4.3', '4.4'],
    WowVersionFamily.mistsOfPandaria: <String>['5.0', '5.1', '5.2', '5.3', '5.4'],
    WowVersionFamily.warlordsOfDraenor: <String>['6.0', '6.1', '6.2'],
    WowVersionFamily.legion: <String>['7.0', '7.1', '7.2', '7.3'],
    WowVersionFamily.battleForAzeroth: <String>['8.0', '8.1', '8.2', '8.3'],
    WowVersionFamily.shadowlands: <String>['9.0', '9.1', '9.2'],
    WowVersionFamily.dragonflight: <String>['10.0', '10.1', '10.2'],
    WowVersionFamily.warWithin: <String>['11.0', '11.1', '11.2'],
    WowVersionFamily.unknown: <String>[],
  };

  static const Map<WowVersionFamily, List<String>> _familyAliases = {
    WowVersionFamily.vanilla: <String>[
      'vanilla',
      'classic era',
      'wow classic era',
      'season of discovery',
      'sod',
    ],
    WowVersionFamily.burningCrusade: <String>[
      'bc',
      'tbc',
      'tbc classic',
      'burning crusade',
      'burning crusade classic',
    ],
    WowVersionFamily.wrath: <String>[
      'wotlk',
      'wrath',
      'wrath classic',
      'wrath of the lich king',
      'lich king',
    ],
    WowVersionFamily.cataclysm: <String>[
      'cata',
      'cataclysm',
      'cata classic',
      'cataclysm classic',
    ],
    WowVersionFamily.mistsOfPandaria: <String>[
      'mop',
      'mist of pandaria',
      'mists of pandaria',
    ],
    WowVersionFamily.warlordsOfDraenor: <String>[
      'wod',
      'warlords of draenor',
    ],
    WowVersionFamily.legion: <String>['legion'],
    WowVersionFamily.battleForAzeroth: <String>[
      'bfa',
      'battle for azeroth',
    ],
    WowVersionFamily.shadowlands: <String>['shadowlands'],
    WowVersionFamily.dragonflight: <String>['dragonflight'],
    WowVersionFamily.warWithin: <String>[
      'war within',
      'the war within',
      'tww',
    ],
    WowVersionFamily.unknown: <String>[],
  };
}
