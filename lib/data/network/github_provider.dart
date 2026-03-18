import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class GitHubProvider implements IAddonProvider {
  static const String staticProviderName = 'GitHub';

  final Dio _dio =
      Dio(
        BaseOptions(
          baseUrl: 'https://api.github.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

  final Dio _archiveDio =
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  @override
  String get providerName => staticProviderName;

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    final normalizedQuery = query.trim();
    final profile = WowVersionProfile.parse(gameVersion);

    if (normalizedQuery.isEmpty || profile.isEmpty) {
      return const <AddonItem>[];
    }

    try {
      final itemsByRepo = <String, Map<String, dynamic>>{};
      for (final searchQuery in _buildSearchQueries(normalizedQuery, profile)) {
        final items = await _performSearch(searchQuery);
        for (final item in items) {
          final fullName = _readString(item['full_name']);
          if (fullName == null) {
            continue;
          }
          itemsByRepo[fullName] = item;
        }

        if (itemsByRepo.length >= 10) {
          break;
        }
      }

      final rankedRepositories = itemsByRepo.values.toList()
        ..sort((a, b) => _scoreRepository(b, profile).compareTo(_scoreRepository(a, profile)));

      final List<AddonItem> results = [];
      for (final item in rankedRepositories) {
        final name = _readString(item['name']);
        if (name == null) {
          continue;
        }

        final description = _readString(item['description']) ?? 'No description available';
        if (_isRepositoryPack(name, description)) {
          continue;
        }

        if (!_matchesRequestedVersion(name, description, profile)) {
          continue;
        }

        final owner = item['owner'] is Map ? Map<String, dynamic>.from(item['owner'] as Map) : const <String, dynamic>{};
        final fullName = _readString(item['full_name']);
        if (fullName == null) {
          continue;
        }

        results.add(AddonItem(
          id: 'gh-${item['id']}',
          name: name,
          summary: description,
          author: _readString(owner['login']),
          thumbnailUrl: _readString(owner['avatar_url']),
          providerName: providerName,
          originalId: fullName,
          version: 'latest',
        ));
      }
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GitHub Search Error: $e');
      }
      return const <AddonItem>[];
    }
  }

  List<String> _buildSearchQueries(String query, WowVersionProfile profile) {
    final numericTokens = profile.apiVersionCandidates.where((token) => token.length >= 3).toList();
    final familyToken = profile.familySearchKeywords.firstWhere(
      (token) => !RegExp(r'^\d').hasMatch(token),
      orElse: () => '',
    );

    final queries = <String>[
      if (numericTokens.isNotEmpty) '$query "${numericTokens.first}" "wow addon" language:Lua',
      if (numericTokens.length > 1) '$query "${numericTokens.last}" addon language:Lua',
      if (familyToken.isNotEmpty) '$query "$familyToken" "wow addon" language:Lua',
      if (familyToken.isNotEmpty) '$query "$familyToken" "world of warcraft"',
    ];

    if (queries.isEmpty) {
      return <String>['$query "wow addon" language:Lua'];
    }

    return queries.toSet().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _performSearch(String query) async {
    try {
      final response = await _dio.get(
        '/search/repositories',
        queryParameters: {
          'q': query,
          'sort': 'stars',
          'order': 'desc',
          'per_page': 10,
        },
      );

      final items = response.data is Map ? response.data['items'] : null;
      if (items is! List) {
        return const <Map<String, dynamic>>[];
      }

      return items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<({String url, String fileName})?> getDownloadUrl(AddonItem item, String gameVersion) async {
    final profile = WowVersionProfile.parse(gameVersion);

    try {
      final response = await _dio.get('/repos/${item.originalId}/releases/latest');
      final assets = response.data is Map ? response.data['assets'] : null;
      final asset = _selectBestZipAsset(assets, profile);

      if (asset != null) {
        final url = _readString(asset['browser_download_url']);
        final fileName = _readString(asset['name']);
        if (url != null && fileName != null) {
          if (kDebugMode) {
            debugPrint('GitHub Release URL: $url');
          }
          return (url: url, fileName: fileName);
        }
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('GitHub Release failed, trying branch fallback for ${item.originalId}');
      }
    }

    return _resolveBranchArchive(item.originalId.toString());
  }

  Map<String, dynamic>? _selectBestZipAsset(Object? assetsData, WowVersionProfile profile) {
    if (assetsData is! List) {
      return null;
    }

    final candidates =
        assetsData
            .whereType<Map>()
            .map((asset) => Map<String, dynamic>.from(asset))
            .where((asset) {
              final name = _readString(asset['name'])?.toLowerCase();
              return name != null && name.endsWith('.zip');
            })
            .toList()
          ..sort((a, b) => _scoreAsset(b, profile).compareTo(_scoreAsset(a, profile)));

    if (candidates.isEmpty) {
      return null;
    }

    final bestCandidate = candidates.first;
    if (_scoreAsset(bestCandidate, profile) < 0) {
      return null;
    }

    return bestCandidate;
  }

  int _scoreAsset(Map<String, dynamic> asset, WowVersionProfile profile) {
    final name = _readString(asset['name']) ?? '';
    final haystack = name.toLowerCase();

    if (profile.containsConflictingVersionMarker(haystack)) {
      return -200;
    }

    final compatibilityScore = profile.numericCompatibilityScore([haystack]);
    if (compatibilityScore >= 100) {
      return compatibilityScore + 20;
    }

    if (profile.containsKnownVersionMarker(haystack)) {
      return -50;
    }

    return 15;
  }

  bool _isRepositoryPack(String name, String description) {
    final haystack = '$name $description'.toLowerCase();
    return haystack.contains('pack') || haystack.contains('collection') || haystack.contains('bundle');
  }

  bool _matchesRequestedVersion(String name, String description, WowVersionProfile profile) {
    final haystack = '$name $description'.toLowerCase();
    if (profile.containsConflictingVersionMarker(haystack)) {
      return false;
    }

    final score = profile.numericCompatibilityScore([haystack]);
    if (score >= 100) {
      return true;
    }

    return !profile.containsKnownVersionMarker(haystack);
  }

  int _scoreRepository(Map<String, dynamic> repository, WowVersionProfile profile) {
    final name = _readString(repository['name']) ?? '';
    final description = _readString(repository['description']) ?? '';
    final haystack = '$name $description'.toLowerCase();

    if (profile.containsConflictingVersionMarker(haystack)) {
      return -200;
    }

    final compatibilityScore = profile.numericCompatibilityScore([haystack]);
    if (compatibilityScore > 0) {
      return compatibilityScore;
    }

    return profile.containsKnownVersionMarker(haystack) ? -40 : 10;
  }

  Future<({String url, String fileName})?> _resolveBranchArchive(String repository) async {
    final defaultBranch = await _fetchDefaultBranch(repository);
    final candidates = <String>[
      ?defaultBranch,
      'main',
      'master',
    ];

    final checkedBranches = <String>{};
    final repositoryName = repository.split('/').last;

    for (final branch in candidates) {
      if (!checkedBranches.add(branch)) {
        continue;
      }

      final url = 'https://github.com/$repository/archive/refs/heads/$branch.zip';
      if (await _branchArchiveExists(url)) {
        return (url: url, fileName: '$repositoryName-$branch.zip');
      }
    }

    return null;
  }

  Future<String?> _fetchDefaultBranch(String repository) async {
    try {
      final response = await _dio.get('/repos/$repository');
      if (response.data is! Map) {
        return null;
      }

      final payload = Map<String, dynamic>.from(response.data as Map);
      return _readString(payload['default_branch']);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _branchArchiveExists(String url) async {
    try {
      final response = await _archiveDio.head(
        url,
        options: Options(
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

  String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue.toLowerCase() == 'null') {
      return null;
    }

    return stringValue;
  }
}
