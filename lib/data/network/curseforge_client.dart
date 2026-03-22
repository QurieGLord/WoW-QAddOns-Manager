import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/utils/request_retry.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_mod.dart';

class CurseForgeClient {
  static const int _searchPageSize = 50;
  static const int _discoveryPageSize = 50;
  static const int _historyPageSize = 200;
  static const int _maxHistoryPages = 10;
  static const int _hintHistoryPages = 4;

  final Dio _dio;
  final Map<String, Future<CfFile?>> _fileMatchCache =
      <String, Future<CfFile?>>{};
  final Map<String, Future<int>> _compatibilityHintCache =
      <String, Future<int>>{};

  CurseForgeClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.curseforge.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'x-api-key': dotenv.env['CURSEFORGE_API_KEY'] ?? '',
          },
        ),
      );

  Future<List<CfMod>> searchMods(
    String query, {
    String? gameVersion,
    ProviderRequestContext? requestContext,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <CfMod>[];
    }

    try {
      final requestedVersion = gameVersion?.trim() ?? '';
      final profile = WowVersionProfile.parse(requestedVersion);
      final queryVariants = _buildSearchQueryVariants(normalizedQuery);
      final attempts = <String?>[
        if (requestedVersion.isNotEmpty &&
            !profile.apiVersionCandidates.contains(
              requestedVersion.toLowerCase(),
            ))
          requestedVersion,
        ...profile.apiVersionCandidates,
        null,
      ];

      final responses = await Future.wait(<Future<List<CfMod>>>[
        for (final attemptVersion in attempts)
          for (final queryVariant in queryVariants)
            _searchModsRequest(
              queryVariant,
              gameVersion: attemptVersion,
              requestContext: requestContext,
            ),
      ]);

      final modsById = <int, CfMod>{};
      for (final mods in responses) {
        for (final mod in mods) {
          modsById.putIfAbsent(mod.id, () => mod);
        }
      }

      return modsById.values.take(_searchPageSize).toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CurseForge Search Error: $e');
      }
      return const <CfMod>[];
    }
  }

  List<String> _buildSearchQueryVariants(String query) {
    final normalizedQuery = query.trim();
    final variants = <String>[];

    void addVariant(String value) {
      final normalizedValue = value.trim();
      if (normalizedValue.isEmpty || variants.contains(normalizedValue)) {
        return;
      }
      variants.add(normalizedValue);
    }

    addVariant(normalizedQuery);

    final tokens = normalizedQuery
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toList(growable: false);

    if (tokens.isEmpty) {
      return variants;
    }

    addVariant(tokens.join(' '));

    if (tokens.length > 1) {
      addVariant(tokens.take(2).join(' '));
      addVariant(tokens.first);
    }

    return variants;
  }

  Future<List<CfMod>> fetchPopularMods(
    String gameVersion, {
    int limit = _discoveryPageSize,
    ProviderRequestContext? requestContext,
  }) async {
    final requestedVersion = gameVersion.trim();
    if (requestedVersion.isEmpty) {
      return const <CfMod>[];
    }

    try {
      final profile = WowVersionProfile.parse(requestedVersion);
      final attempts = <String?>[
        if (!profile.apiVersionCandidates.contains(
          requestedVersion.toLowerCase(),
        ))
          requestedVersion,
        ...profile.apiVersionCandidates,
        null,
      ];

      final responses = await Future.wait(
        attempts.map(
          (attemptVersion) => _searchModsRequest(
            '',
            gameVersion: attemptVersion,
            pageSize: limit.clamp(1, _discoveryPageSize),
            sortField: 2,
            requestContext: requestContext,
          ),
        ),
      );

      final modsById = <int, CfMod>{};
      for (final mods in responses) {
        for (final mod in mods) {
          modsById.putIfAbsent(mod.id, () => mod);
        }
      }

      return modsById.values.take(limit).toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CurseForge Discovery Error: $e');
      }
      return const <CfMod>[];
    }
  }

  Future<CfFile?> getLatestFileForVersion(
    int modId,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return Future<CfFile?>.value(null);
    }

    final cacheKey = '$modId|$normalizedVersion';
    return _fileMatchCache.putIfAbsent(
      cacheKey,
      () => _loadLatestFileForVersion(
        modId,
        normalizedVersion,
        requestContext: requestContext,
      ),
    );
  }

  CfFile? getPreviewFileForVersion(CfMod mod, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return null;
    }

    final profile = WowVersionProfile.parse(normalizedVersion);
    final rankedCandidates = _rankCandidates(mod.latestFiles, profile);
    return rankedCandidates.isEmpty ? null : rankedCandidates.first.file;
  }

  int getPreviewEvidenceScore(CfMod mod, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return 0;
    }

    final profile = WowVersionProfile.parse(normalizedVersion);
    final previewFile = getPreviewFileForVersion(mod, normalizedVersion);
    return previewFile == null ? 0 : _scoreFile(previewFile, profile);
  }

  int getMetadataCompatibilityScore(CfMod mod, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return 0;
    }

    final profile = WowVersionProfile.parse(normalizedVersion);
    final metadataHaystack = '${mod.name} ${mod.summary}'.toLowerCase();
    if (profile.containsConflictingVersionMarker(metadataHaystack)) {
      return 0;
    }

    final metadataScore = profile.numericCompatibilityScore(<String>[
      mod.name,
      mod.summary,
    ]);

    if (metadataScore > 0) {
      return metadataScore;
    }

    return profile.containsKnownVersionMarker(metadataHaystack) ? 0 : 10;
  }

  int getPreviewCompatibilityScore(CfMod mod, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return 0;
    }

    final previewScore = getPreviewEvidenceScore(mod, normalizedVersion);
    final metadataScore = getMetadataCompatibilityScore(mod, normalizedVersion);
    return previewScore > metadataScore ? previewScore : metadataScore;
  }

  Future<int> getCompatibilityHintScore(int modId, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return Future<int>.value(0);
    }

    final cacheKey = '$modId|$normalizedVersion|hint';
    return _compatibilityHintCache.putIfAbsent(
      cacheKey,
      () => _loadCompatibilityHintScore(modId, normalizedVersion),
    );
  }

  Future<CfFile?> _loadLatestFileForVersion(
    int modId,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final profile = WowVersionProfile.parse(gameVersion);

      final targetedFiles = <int, CfFile>{};
      for (final version in <String>[
        if (!profile.apiVersionCandidates.contains(gameVersion)) gameVersion,
        ...profile.apiVersionCandidates,
      ]) {
        final files = await _fetchFiles(
          modId,
          gameVersion: version,
          requestContext: requestContext,
        );
        for (final file in files) {
          targetedFiles[file.id] = file;
        }
      }

      final targetedMatch = await _selectBestMatchingFile(
        modId,
        targetedFiles.values,
        profile,
        requestContext: requestContext,
      );
      final targetedScore = targetedMatch == null
          ? 0
          : _scoreFile(targetedMatch, profile);
      if (targetedScore >= 100) {
        return targetedMatch;
      }

      final historicalMatch = await _scanHistoricalFiles(
        modId,
        profile,
        requestContext: requestContext,
      );
      if (historicalMatch == null) {
        return targetedMatch;
      }

      final historicalScore = _scoreFile(historicalMatch, profile);
      if (historicalScore > targetedScore) {
        return historicalMatch;
      }

      return targetedMatch ?? historicalMatch;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CurseForge File Match Error ($modId / $gameVersion): $e');
      }
      return null;
    }
  }

  Future<int> _loadCompatibilityHintScore(int modId, String gameVersion) async {
    try {
      final profile = WowVersionProfile.parse(gameVersion);
      var bestScore = 0;

      final targetedFiles = <int, CfFile>{};
      for (final version in <String>[
        if (!profile.apiVersionCandidates.contains(gameVersion)) gameVersion,
        ...profile.apiVersionCandidates,
      ]) {
        final files = await _fetchFiles(modId, gameVersion: version);
        for (final file in files) {
          targetedFiles[file.id] = file;
        }
      }

      final targetedCandidates = _rankCandidates(targetedFiles.values, profile);
      if (targetedCandidates.isNotEmpty) {
        bestScore = targetedCandidates.first.score;
        if (bestScore >= 100) {
          return bestScore;
        }
      }

      for (var page = 0; page < _hintHistoryPages; page++) {
        final files = await _fetchFiles(modId, index: page * _historyPageSize);
        if (files.isEmpty) {
          break;
        }

        final rankedCandidates = _rankCandidates(files, profile);
        if (rankedCandidates.isNotEmpty &&
            rankedCandidates.first.score > bestScore) {
          bestScore = rankedCandidates.first.score;
          if (bestScore >= 100) {
            return bestScore;
          }
        }

        if (files.length < _historyPageSize) {
          break;
        }
      }

      return bestScore;
    } catch (_) {
      return 0;
    }
  }

  Future<List<CfMod>> _searchModsRequest(
    String query, {
    String? gameVersion,
    int pageSize = _searchPageSize,
    int sortField = 2,
    ProviderRequestContext? requestContext,
  }) async {
    final queryParams = <String, dynamic>{
      'gameId': 1,
      'sortField': sortField,
      'sortOrder': 'desc',
      'pageSize': pageSize.clamp(1, _searchPageSize),
    };

    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      queryParams['searchFilter'] = normalizedQuery;
    }

    if (gameVersion != null && gameVersion.isNotEmpty) {
      queryParams['gameVersion'] = gameVersion;
    }

    final response = await executeWithRetry<Response<dynamic>>(
      requestContext: requestContext,
      task: (cancelToken, timeout) => _dio.get(
        '/v1/mods/search',
        queryParameters: queryParams,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      ),
    );
    return _readObjectList(
      response.data,
    ).map(CfMod.fromJson).toList(growable: false);
  }

  Future<List<CfFile>> _fetchFiles(
    int modId, {
    String? gameVersion,
    int pageSize = _historyPageSize,
    int index = 0,
    ProviderRequestContext? requestContext,
  }) async {
    final queryParams = <String, dynamic>{'pageSize': pageSize, 'index': index};

    if (gameVersion != null && gameVersion.isNotEmpty) {
      queryParams['gameVersion'] = gameVersion;
    }

    final response = await executeWithRetry<Response<dynamic>>(
      requestContext: requestContext,
      task: (cancelToken, timeout) => _dio.get(
        '/v1/mods/$modId/files',
        queryParameters: queryParams,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      ),
    );
    return _readObjectList(
      response.data,
    ).map(CfFile.fromJson).toList(growable: false);
  }

  Future<CfFile?> _scanHistoricalFiles(
    int modId,
    WowVersionProfile profile, {
    ProviderRequestContext? requestContext,
  }) async {
    CfFile? bestMatch;
    var bestScore = 0;

    for (var page = 0; page < _maxHistoryPages; page++) {
      final index = page * _historyPageSize;
      final files = await _fetchFiles(
        modId,
        index: index,
        requestContext: requestContext,
      );
      if (files.isEmpty) {
        break;
      }

      final rankedCandidates = _rankCandidates(files, profile);
      if (rankedCandidates.isNotEmpty) {
        final highestPageScore = rankedCandidates.first.score;
        final pageMatch = await _resolveRankedCandidates(
          modId,
          rankedCandidates,
          requestContext: requestContext,
        );
        if (pageMatch != null) {
          if (highestPageScore > bestScore || bestMatch == null) {
            bestScore = highestPageScore;
            bestMatch = pageMatch;
          }

          if (highestPageScore >= 100) {
            return pageMatch;
          }
        }
      }

      if (files.length < _historyPageSize) {
        break;
      }
    }

    return bestMatch;
  }

  Future<CfFile?> _selectBestMatchingFile(
    int modId,
    Iterable<CfFile> files,
    WowVersionProfile profile, {
    ProviderRequestContext? requestContext,
  }) async {
    return _resolveRankedCandidates(
      modId,
      _rankCandidates(files, profile),
      requestContext: requestContext,
    );
  }

  List<({CfFile file, int score})> _rankCandidates(
    Iterable<CfFile> files,
    WowVersionProfile profile,
  ) {
    final rankedCandidates =
        files
            .map((file) => (file: file, score: _scoreFile(file, profile)))
            .where((candidate) => candidate.score > 0)
            .toList()
          ..sort((a, b) {
            final scoreComparison = b.score.compareTo(a.score);
            if (scoreComparison != 0) {
              return scoreComparison;
            }
            return b.file.id.compareTo(a.file.id);
          });

    return rankedCandidates;
  }

  Future<CfFile?> _resolveRankedCandidates(
    int modId,
    List<({CfFile file, int score})> rankedCandidates, {
    ProviderRequestContext? requestContext,
  }) async {
    for (final candidate in rankedCandidates) {
      final resolvedUrl = await _resolveDownloadUrl(
        modId,
        candidate.file,
        requestContext: requestContext,
      );
      if (resolvedUrl == null) {
        continue;
      }

      if (kDebugMode) {
        debugPrint(
          'CurseForge Match: ${candidate.file.fileName} -> $resolvedUrl',
        );
      }

      return candidate.file.copyWith(downloadUrl: resolvedUrl);
    }

    return null;
  }

  int _scoreFile(CfFile file, WowVersionProfile profile) {
    final explicitVersions = file.gameVersions
        .where((version) => version.trim().isNotEmpty)
        .toList(growable: false);
    final descriptiveMetadata = <String>[
      if (file.displayName != null) file.displayName!,
      file.fileName,
    ];

    final explicitScore = profile.numericCompatibilityScore(explicitVersions);
    final descriptiveScore = profile.numericCompatibilityScore(
      descriptiveMetadata,
    );
    final hasStrictExplicitMatch = explicitVersions.any(
      (version) => _matchesRequestedBranch(version, profile),
    );
    final hasConflictingExplicitVersion = explicitVersions.any(
      profile.containsConflictingVersionMarker,
    );

    if (hasConflictingExplicitVersion && !hasStrictExplicitMatch) {
      return 0;
    }

    var score = 0;
    if (hasStrictExplicitMatch) {
      score = explicitScore + 60;

      if (explicitVersions.any(
        (version) => _matchesExactVersion(version, profile),
      )) {
        score += 40;
      } else {
        score += 20;
      }
    } else if (explicitScore > 0) {
      score = explicitScore + 25;
    }

    if (descriptiveScore > 0) {
      final descriptiveBonus =
          (file.displayName != null &&
              profile.containsRequestedVersion(file.displayName!))
          ? 15
          : profile.containsRequestedVersion(file.fileName)
          ? 10
          : 0;
      score = score < descriptiveScore + descriptiveBonus
          ? descriptiveScore + descriptiveBonus
          : score + descriptiveBonus;
    } else if (score == 0) {
      final descriptiveHaystack = descriptiveMetadata.join(' ');
      if (profile.containsKnownVersionMarker(descriptiveHaystack)) {
        return 0;
      }
    }

    return score;
  }

  bool _matchesRequestedBranch(String value, WowVersionProfile profile) {
    final candidate = WowVersionProfile.parse(value);
    if (candidate.hasNumericVersion &&
        candidate.majorMinor == profile.majorMinor) {
      return true;
    }

    return profile.numericCompatibilityScore(<String>[value]) >= 100 &&
        !profile.containsConflictingVersionMarker(value);
  }

  bool _matchesExactVersion(String value, WowVersionProfile profile) {
    if (profile.exactVersion == profile.majorMinor) {
      return false;
    }

    final candidate = WowVersionProfile.parse(value);
    return candidate.hasNumericVersion &&
        candidate.exactVersion == profile.exactVersion;
  }

  Future<String?> _resolveDownloadUrl(
    int modId,
    CfFile file, {
    ProviderRequestContext? requestContext,
  }) async {
    final directUrl = _normalizeUrl(file.downloadUrl);
    if (directUrl != null) {
      return directUrl;
    }

    final apiUrl = await _fetchDirectDownloadUrl(
      modId,
      file.id,
      requestContext: requestContext,
    );
    if (apiUrl != null) {
      return apiUrl;
    }

    return _resolveLegacyDownloadUrl(
      file.id,
      file.fileName,
      requestContext: requestContext,
    );
  }

  Future<String?> _fetchDirectDownloadUrl(
    int modId,
    int fileId, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.get(
          '/v1/mods/$modId/files/$fileId/download-url',
          cancelToken: cancelToken,
          options: Options(receiveTimeout: timeout, sendTimeout: timeout),
        ),
      );
      final data = response.data;

      if (data is String) {
        return _normalizeUrl(data);
      }

      if (data is Map) {
        final typedData = Map<String, dynamic>.from(data);
        return _normalizeUrl(typedData['data']?.toString());
      }
    } catch (_) {
      // Ignore and fallback to legacy CDN URL generation.
    }

    return null;
  }

  Future<String?> _resolveLegacyDownloadUrl(
    int fileId,
    String fileName, {
    ProviderRequestContext? requestContext,
  }) async {
    final candidates = _buildLegacyDownloadUrlCandidates(fileId, fileName);
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      if (await _isDownloadUrlReachable(
        candidate,
        requestContext: requestContext,
      )) {
        return candidate;
      }
    }

    return candidates.first;
  }

  List<String> _buildLegacyDownloadUrlCandidates(int fileId, String fileName) {
    final fileIdString = fileId.toString();
    if (fileIdString.length <= 3 || fileName.trim().isEmpty) {
      return const <String>[];
    }

    final prefix = fileIdString.substring(0, fileIdString.length - 3);
    final suffixRaw = fileIdString.substring(fileIdString.length - 3);
    final suffixTrimmed = int.tryParse(suffixRaw)?.toString() ?? suffixRaw;
    final encodedFileName = Uri.encodeComponent(fileName.trim());

    final urls = <String>[
      'https://edge.forgecdn.net/files/$prefix/$suffixRaw/$encodedFileName',
      if (suffixTrimmed != suffixRaw)
        'https://edge.forgecdn.net/files/$prefix/$suffixTrimmed/$encodedFileName',
      'https://mediafiles.forgecdn.net/files/$prefix/$suffixTrimmed/$encodedFileName',
    ];

    return urls.toSet().toList(growable: false);
  }

  Future<bool> _isDownloadUrlReachable(
    String url, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.requestUri(
          Uri.parse(url),
          cancelToken: cancelToken,
          options: Options(
            method: 'HEAD',
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            receiveTimeout: timeout,
            sendTimeout: timeout,
          ),
        ),
      );

      final statusCode = response.statusCode ?? 0;
      return statusCode == 200 || statusCode == 301 || statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  String? _normalizeUrl(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  List<Map<String, dynamic>> _readObjectList(dynamic responseData) {
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! List) {
      return const <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}
