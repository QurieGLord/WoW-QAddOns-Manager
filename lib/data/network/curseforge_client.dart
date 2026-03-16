import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_file.dart';
import 'package:wow_qaddons_manager/domain/models/curseforge/cf_mod.dart';

class CurseForgeClient {
  static const int _searchPageSize = 20;
  static const int _historyPageSize = 200;
  static const int _maxHistoryPages = 6;

  final Dio _dio;
  final Map<String, Future<CfFile?>> _fileMatchCache = <String, Future<CfFile?>>{};

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

  Future<List<CfMod>> searchMods(String query, {String? gameVersion}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <CfMod>[];
    }

    try {
      final requestedVersion = gameVersion?.trim() ?? '';
      final profile = WowVersionProfile.parse(requestedVersion);
      final attempts = <String?>[
        if (requestedVersion.isNotEmpty) requestedVersion,
        if (profile.majorMinor.isNotEmpty && profile.majorMinor != requestedVersion) profile.majorMinor,
        null,
      ];

      final modsById = <int, CfMod>{};
      for (final attemptVersion in attempts) {
        final mods = await _searchModsRequest(normalizedQuery, gameVersion: attemptVersion);
        for (final mod in mods) {
          modsById.putIfAbsent(mod.id, () => mod);
        }

        if (modsById.length >= _searchPageSize) {
          break;
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

  Future<CfFile?> getLatestFileForVersion(int modId, String gameVersion) {
    final normalizedVersion = gameVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty) {
      return Future<CfFile?>.value(null);
    }

    final cacheKey = '$modId|$normalizedVersion';
    return _fileMatchCache.putIfAbsent(
      cacheKey,
      () => _loadLatestFileForVersion(modId, normalizedVersion),
    );
  }

  Future<CfFile?> _loadLatestFileForVersion(int modId, String gameVersion) async {
    try {
      final profile = WowVersionProfile.parse(gameVersion);

      final targetedFiles = <int, CfFile>{};
      for (final version in <String>[
        gameVersion,
        if (profile.majorMinor.isNotEmpty && profile.majorMinor != gameVersion) profile.majorMinor,
      ]) {
        final files = await _fetchFiles(modId, gameVersion: version);
        for (final file in files) {
          targetedFiles[file.id] = file;
        }
      }

      final targetedMatch = await _selectBestMatchingFile(modId, targetedFiles.values, profile);
      final targetedScore = targetedMatch == null ? 0 : _scoreFile(targetedMatch, profile);
      if (targetedScore >= 100) {
        return targetedMatch;
      }

      final historicalMatch = await _scanHistoricalFiles(modId, profile);
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

  Future<List<CfMod>> _searchModsRequest(String query, {String? gameVersion}) async {
    final queryParams = <String, dynamic>{
      'gameId': 1,
      'searchFilter': query,
      'sortField': 2,
      'sortOrder': 'desc',
      'pageSize': _searchPageSize,
    };

    if (gameVersion != null && gameVersion.isNotEmpty) {
      queryParams['gameVersion'] = gameVersion;
    }

    final response = await _dio.get('/v1/mods/search', queryParameters: queryParams);
    return _readObjectList(response.data).map(CfMod.fromJson).toList(growable: false);
  }

  Future<List<CfFile>> _fetchFiles(
    int modId, {
    String? gameVersion,
    int pageSize = _historyPageSize,
    int index = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'pageSize': pageSize,
      'index': index,
    };

    if (gameVersion != null && gameVersion.isNotEmpty) {
      queryParams['gameVersion'] = gameVersion;
    }

    final response = await _dio.get('/v1/mods/$modId/files', queryParameters: queryParams);
    return _readObjectList(response.data).map(CfFile.fromJson).toList(growable: false);
  }

  Future<CfFile?> _scanHistoricalFiles(int modId, WowVersionProfile profile) async {
    CfFile? bestMatch;
    var bestScore = 0;

    for (var page = 0; page < _maxHistoryPages; page++) {
      final index = page * _historyPageSize;
      final files = await _fetchFiles(modId, index: index);
      if (files.isEmpty) {
        break;
      }

      final rankedCandidates = _rankCandidates(files, profile);
      if (rankedCandidates.isNotEmpty) {
        final highestPageScore = rankedCandidates.first.score;
        final pageMatch = await _resolveRankedCandidates(modId, rankedCandidates);
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
    WowVersionProfile profile,
  ) async {
    return _resolveRankedCandidates(modId, _rankCandidates(files, profile));
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
    List<({CfFile file, int score})> rankedCandidates,
  ) async {
    for (final candidate in rankedCandidates) {
      final resolvedUrl = await _resolveDownloadUrl(modId, candidate.file);
      if (resolvedUrl == null) {
        continue;
      }

      if (kDebugMode) {
        debugPrint('CurseForge Match: ${candidate.file.fileName} -> $resolvedUrl');
      }

      return candidate.file.copyWith(downloadUrl: resolvedUrl);
    }

    return null;
  }

  int _scoreFile(CfFile file, WowVersionProfile profile) {
    final metadata = <String>[
      ...file.gameVersions,
      if (file.displayName != null) file.displayName!,
      file.fileName,
    ];

    var score = profile.numericCompatibilityScore(metadata);
    if (score == 0) {
      return 0;
    }

    if (file.displayName != null && profile.containsRequestedVersion(file.displayName!)) {
      score += 10;
    }

    if (profile.containsRequestedVersion(file.fileName)) {
      score += 5;
    }

    return score;
  }

  Future<String?> _resolveDownloadUrl(int modId, CfFile file) async {
    final directUrl = _normalizeUrl(file.downloadUrl);
    if (directUrl != null) {
      return directUrl;
    }

    final apiUrl = await _fetchDirectDownloadUrl(modId, file.id);
    if (apiUrl != null) {
      return apiUrl;
    }

    return _resolveLegacyDownloadUrl(file.id, file.fileName);
  }

  Future<String?> _fetchDirectDownloadUrl(int modId, int fileId) async {
    try {
      final response = await _dio.get('/v1/mods/$modId/files/$fileId/download-url');
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

  Future<String?> _resolveLegacyDownloadUrl(int fileId, String fileName) async {
    final candidates = _buildLegacyDownloadUrlCandidates(fileId, fileName);
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      if (await _isDownloadUrlReachable(candidate)) {
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
      if (suffixTrimmed != suffixRaw) 'https://edge.forgecdn.net/files/$prefix/$suffixTrimmed/$encodedFileName',
      'https://mediafiles.forgecdn.net/files/$prefix/$suffixTrimmed/$encodedFileName',
    ];

    return urls.toSet().toList(growable: false);
  }

  Future<bool> _isDownloadUrlReachable(String url) async {
    try {
      final response = await _dio.requestUri(
        Uri.parse(url),
        options: Options(
          method: 'HEAD',
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
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

    return data.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList(growable: false);
  }
}
