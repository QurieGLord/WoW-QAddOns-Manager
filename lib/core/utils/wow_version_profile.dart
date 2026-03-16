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
    required this.majorMinor,
    required this.major,
    required this.minor,
    required this.family,
  });

  factory WowVersionProfile.parse(String version) {
    final normalized = version.trim().toLowerCase();
    final matches = RegExp(r'\d+').allMatches(normalized).map((match) => int.tryParse(match.group(0)!)).whereType<int>().toList();

    final major = matches.isNotEmpty ? matches[0] : null;
    final minor = matches.length > 1 ? matches[1] : null;
    final majorMinor = major != null && minor != null ? '$major.$minor' : normalized;

    return WowVersionProfile._(
      rawVersion: version,
      normalizedVersion: normalized,
      majorMinor: majorMinor,
      major: major,
      minor: minor,
      family: _familyFromMajor(major),
    );
  }

  final String rawVersion;
  final String normalizedVersion;
  final String majorMinor;
  final int? major;
  final int? minor;
  final WowVersionFamily family;

  bool get isEmpty => normalizedVersion.isEmpty;

  bool get isRetailEra => (major ?? 0) >= 8;

  List<String> get searchVersionTokens {
    final tokens = <String>[];
    if (majorMinor.isNotEmpty) {
      tokens.add(majorMinor);
    }
    if (normalizedVersion.isNotEmpty && normalizedVersion != majorMinor) {
      tokens.add(normalizedVersion);
    }
    return tokens;
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
    for (final tokens in _versionMarkers.values) {
      for (final token in tokens) {
        if (_containsToken(haystack, token)) {
          return true;
        }
      }
    }
    if (!isRetailEra && _containsToken(haystack, 'retail')) {
      return true;
    }
    return false;
  }

  bool containsConflictingVersionMarker(String text) {
    final haystack = text.toLowerCase();

    for (final entry in _versionMarkers.entries) {
      if (entry.key == family) {
        continue;
      }
      for (final token in entry.value) {
        if (_containsToken(haystack, token)) {
          return true;
        }
      }
    }

    if (!isRetailEra && _containsToken(haystack, 'retail')) {
      return true;
    }

    return false;
  }

  int numericCompatibilityScore(Iterable<String> values) {
    var score = 0;

    for (final value in values) {
      final haystack = value.toLowerCase();

      if (normalizedVersion.isNotEmpty && _containsToken(haystack, normalizedVersion)) {
        score = score < 100 ? 100 : score;
      }

      if (majorMinor.isNotEmpty && _containsToken(haystack, majorMinor)) {
        score = score < 80 ? 80 : score;
      }
    }

    return score;
  }

  static bool _containsToken(String text, String token) {
    if (token.isEmpty) {
      return false;
    }

    final expression = RegExp(
      '(?<![a-z0-9])${RegExp.escape(token.toLowerCase())}(?![a-z0-9])',
      caseSensitive: false,
    );

    return expression.hasMatch(text);
  }

  static WowVersionFamily _familyFromMajor(int? major) {
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

  static const Map<WowVersionFamily, List<String>> _versionMarkers = {
    WowVersionFamily.vanilla: <String>[
      '1.12',
      '1.13',
      '1.14',
      'classic era',
      'vanilla',
      'era',
    ],
    WowVersionFamily.burningCrusade: <String>[
      '2.4',
      '2.5',
      'bc',
      'tbc',
      'burning crusade',
    ],
    WowVersionFamily.wrath: <String>[
      '3.3',
      '3.4',
      'wotlk',
      'wrath',
      'wrath of the lich king',
    ],
    WowVersionFamily.cataclysm: <String>[
      '4.3',
      '4.4',
      'cata',
      'cataclysm',
    ],
    WowVersionFamily.mistsOfPandaria: <String>[
      '5.4',
      'mop',
      'mist of pandaria',
      'mists of pandaria',
      'pandaria',
    ],
    WowVersionFamily.warlordsOfDraenor: <String>[
      '6.0',
      '6.1',
      '6.2',
      'wod',
      'warlords',
      'warlords of draenor',
    ],
    WowVersionFamily.legion: <String>[
      '7.0',
      '7.1',
      '7.2',
      '7.3',
      'legion',
    ],
    WowVersionFamily.battleForAzeroth: <String>[
      '8.0',
      '8.1',
      '8.2',
      '8.3',
      'bfa',
      'battle for azeroth',
    ],
    WowVersionFamily.shadowlands: <String>[
      '9.0',
      '9.1',
      '9.2',
      'shadowlands',
    ],
    WowVersionFamily.dragonflight: <String>[
      '10.0',
      '10.1',
      '10.2',
      '10.3',
      'dragonflight',
    ],
    WowVersionFamily.warWithin: <String>[
      '11.0',
      '11.1',
      'war within',
      'the war within',
    ],
    WowVersionFamily.unknown: <String>[],
  };
}
