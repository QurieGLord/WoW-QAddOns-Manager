import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/utils/request_retry.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class GitHubProvider extends IAddonProvider {
  static const String staticProviderName = 'GitHub';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    ),
  );

  final Dio _archiveDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  String get providerName => staticProviderName;

  @override
  bool get supportsDiscoveryFeed => false;

  @override
  Future<List<AddonItem>> search(String query, String gameVersion) async {
    return searchWithContext(query, gameVersion);
  }

  Future<List<AddonItem>> searchWithContext(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    final normalizedQuery = query.trim();
    final profile = WowVersionProfile.parse(gameVersion);

    if (normalizedQuery.isEmpty || profile.isEmpty) {
      return const <AddonItem>[];
    }

    try {
      final searchQueries = _buildSearchQueries(normalizedQuery, profile);
      final queryResults = await Future.wait(
        searchQueries.map(
          (searchQuery) =>
              _performSearch(searchQuery, requestContext: requestContext),
        ),
      );

      final itemsByRepo = <String, Map<String, dynamic>>{};
      for (final items in queryResults) {
        for (final item in items) {
          final fullName = _readString(item['full_name']);
          if (fullName == null) {
            continue;
          }
          itemsByRepo[fullName] = item;
        }
      }

      final rankedRepositories = itemsByRepo.values.toList()
        ..sort(
          (a, b) => _scoreRepository(
            b,
            profile,
            normalizedQuery,
          ).compareTo(_scoreRepository(a, profile, normalizedQuery)),
        );

      final List<AddonItem> results = [];
      for (final item in rankedRepositories) {
        final name = _readString(item['name']);
        if (name == null) {
          continue;
        }

        final description = _readString(item['description']) ?? '';
        if (_isRepositoryPack(name, description)) {
          continue;
        }

        if (!_matchesRequestedVersion(name, description, profile)) {
          continue;
        }

        final owner = item['owner'] is Map
            ? Map<String, dynamic>.from(item['owner'] as Map)
            : const <String, dynamic>{};
        final fullName = _readString(item['full_name']);
        if (fullName == null) {
          continue;
        }

        results.add(
          AddonItem(
            id: 'gh-${item['id']}',
            name: name,
            summary: description,
            author: _readString(owner['login']),
            thumbnailUrl: _readString(owner['avatar_url']),
            providerName: providerName,
            originalId: fullName,
            sourceSlug: fullName.split('/').last,
            identityHints: <String>[name, fullName, fullName.split('/').last],
            version: 'latest',
          ),
        );
      }
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GitHub Search Error: $e');
      }
      return const <AddonItem>[];
    }
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
  }) async {
    return const <AddonItem>[];
  }

  List<String> _buildSearchQueries(String query, WowVersionProfile profile) {
    final numericTokens = profile.apiVersionCandidates
        .where((token) => token.length >= 3)
        .toList();
    final familyToken = profile.familySearchKeywords.firstWhere(
      (token) => !RegExp(r'^\d').hasMatch(token),
      orElse: () => '',
    );

    final queries = <String>[
      if (numericTokens.isNotEmpty)
        '$query "${numericTokens.first}" "wow addon" language:Lua',
      if (numericTokens.length > 1)
        '$query "${numericTokens.last}" addon language:Lua',
      if (familyToken.isNotEmpty)
        '$query "$familyToken" "wow addon" language:Lua',
      if (familyToken.isNotEmpty) '$query "$familyToken" "world of warcraft"',
      if (profile.isRetailEra) '$query "retail" "wow addon" language:Lua',
      if (profile.isRetailEra) '$query "retail" "world of warcraft"',
      '$query "wow addon" language:Lua',
      '$query "world of warcraft addon"',
    ];

    return queries.toSet().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _performSearch(
    String query, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.get(
          '/search/repositories',
          queryParameters: {
            'q': query,
            'sort': 'stars',
            'order': 'desc',
            'per_page': 20,
          },
          cancelToken: cancelToken,
          options: Options(receiveTimeout: timeout, sendTimeout: timeout),
        ),
      );

      final items = response.data is Map ? response.data['items'] : null;
      if (items is! List) {
        return const <Map<String, dynamic>>[];
      }

      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
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

    final profile = WowVersionProfile.parse(gameVersion);

    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.get(
          '/repos/${item.originalId}/releases/latest',
          cancelToken: cancelToken,
          options: Options(receiveTimeout: timeout, sendTimeout: timeout),
        ),
      );
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
        debugPrint(
          'GitHub Release failed, trying branch fallback for ${item.originalId}',
        );
      }
    }

    return _resolveBranchArchive(
      item.originalId.toString(),
      requestContext: requestContext,
    );
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

    final info = await getDownloadUrlWithContext(
      item,
      gameVersion,
      requestContext: requestContext,
    );
    if (info == null || info.url.isEmpty || info.fileName.isEmpty) {
      return null;
    }

    return item.copyWith(
      verifiedDownloadUrl: info.url,
      verifiedFileName: info.fileName,
    );
  }

  Map<String, dynamic>? _selectBestZipAsset(
    Object? assetsData,
    WowVersionProfile profile,
  ) {
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
          ..sort(
            (a, b) =>
                _scoreAsset(b, profile).compareTo(_scoreAsset(a, profile)),
          );

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
    return haystack.contains('pack') ||
        haystack.contains('collection') ||
        haystack.contains('bundle');
  }

  bool _matchesRequestedVersion(
    String name,
    String description,
    WowVersionProfile profile,
  ) {
    final haystack = '$name $description'.toLowerCase();
    if (_hasRequestedMarker(name, description, profile)) {
      return true;
    }

    if (profile.containsConflictingVersionMarker(haystack)) {
      return false;
    }

    return !profile.containsKnownVersionMarker(haystack);
  }

  int _scoreRepository(
    Map<String, dynamic> repository,
    WowVersionProfile profile,
    String normalizedQuery,
  ) {
    final name = _readString(repository['name']) ?? '';
    final description = _readString(repository['description']) ?? '';
    final fullName = _readString(repository['full_name']) ?? name;
    final haystack = '$name $description'.toLowerCase();
    final hasRequestedMarker = _hasRequestedMarker(name, description, profile);

    final compatibilityScore = profile.numericCompatibilityScore(<String>[
      name,
      description,
    ]);

    if (!hasRequestedMarker &&
        compatibilityScore == 0 &&
        profile.containsConflictingVersionMarker(haystack)) {
      return -200;
    }

    var score = _scoreQueryRelevance(name, description, normalizedQuery);
    score += _scoreCanonicalRepository(name, fullName, normalizedQuery);

    if (compatibilityScore > 0) {
      score += compatibilityScore * 2;
    } else if (hasRequestedMarker) {
      score += 140;
    } else if (profile.containsKnownVersionMarker(haystack)) {
      score -= 40;
    }

    if (_looksLikeDerivativeRepository(name, normalizedQuery)) {
      score -= 30;
    }

    if (_readBool(repository['archived'])) {
      score -= 120;
    }

    final stars = repository['stargazers_count'];
    if (stars is num) {
      final starBonus = (stars / 250).floor();
      score += starBonus > 30 ? 30 : starBonus;
    }

    return score;
  }

  Future<({String url, String fileName})?> _resolveBranchArchive(
    String repository, {
    ProviderRequestContext? requestContext,
  }) async {
    final defaultBranch = await _fetchDefaultBranch(
      repository,
      requestContext: requestContext,
    );
    final candidates = <String>[?defaultBranch, 'main', 'master'];

    final checkedBranches = <String>{};
    final repositoryName = repository.split('/').last;

    for (final branch in candidates) {
      if (!checkedBranches.add(branch)) {
        continue;
      }

      final url =
          'https://github.com/$repository/archive/refs/heads/$branch.zip';
      if (await _branchArchiveExists(url, requestContext: requestContext)) {
        return (url: url, fileName: '$repositoryName-$branch.zip');
      }
    }

    return null;
  }

  Future<String?> _fetchDefaultBranch(
    String repository, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.get(
          '/repos/$repository',
          cancelToken: cancelToken,
          options: Options(receiveTimeout: timeout, sendTimeout: timeout),
        ),
      );
      if (response.data is! Map) {
        return null;
      }

      final payload = Map<String, dynamic>.from(response.data as Map);
      return _readString(payload['default_branch']);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _branchArchiveExists(
    String url, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final response = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _archiveDio.head(
          url,
          cancelToken: cancelToken,
          options: Options(
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

  bool _readBool(Object? value) {
    return value is bool ? value : false;
  }

  bool _hasRequestedMarker(
    String name,
    String description,
    WowVersionProfile profile,
  ) {
    return profile.containsRequestedVersion(name) ||
        profile.containsRequestedVersion(description);
  }

  int _scoreQueryRelevance(String name, String description, String query) {
    final normalizedName = _normalizeIdentity(name);
    final normalizedDescription = _normalizeIdentity(description);
    final normalizedQuery = _normalizeIdentity(query);
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    if (normalizedName == normalizedQuery) {
      return 260;
    }
    if (normalizedName.startsWith(normalizedQuery)) {
      return 180;
    }
    if (normalizedName.contains(normalizedQuery)) {
      return 120;
    }
    if (normalizedDescription.contains(normalizedQuery)) {
      return 50;
    }
    return 0;
  }

  int _scoreCanonicalRepository(String name, String fullName, String query) {
    final normalizedQuery = _normalizeIdentity(query);
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final normalizedName = _normalizeIdentity(name);
    final normalizedSlug = _normalizeIdentity(fullName.split('/').last);
    if (normalizedSlug == normalizedQuery) {
      return 140;
    }
    if (normalizedName == normalizedQuery) {
      return 120;
    }
    if (normalizedSlug.startsWith(normalizedQuery)) {
      return 70;
    }
    return 0;
  }

  bool _looksLikeDerivativeRepository(String name, String query) {
    final normalizedName = _normalizeIdentity(name);
    final normalizedQuery = _normalizeIdentity(query);
    if (normalizedQuery.isEmpty || normalizedName == normalizedQuery) {
      return false;
    }
    if (!normalizedName.startsWith(normalizedQuery)) {
      return false;
    }

    return RegExp(
      r'(classic|era|bc|tbc|wrath|wotlk|cata|mop|bfa|retail|ptr|fork|continued|community|reborn|plus|edit|mod|edition)$',
      caseSensitive: false,
    ).hasMatch(normalizedName);
  }

  String _normalizeIdentity(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }
}
