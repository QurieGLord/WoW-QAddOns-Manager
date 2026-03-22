import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/utils/request_retry.dart';
import 'package:wow_qaddons_manager/core/utils/wow_version_profile.dart';
import 'package:wow_qaddons_manager/domain/interfaces/addon_provider.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';

class WowskillProvider extends IAddonProvider {
  static const String staticProviderName = 'Wowskill';
  static const Duration _negativeDetailCacheTtl = Duration(minutes: 2);
  static const Duration _positiveProbeCacheTtl = Duration(minutes: 20);
  static const Duration _negativeProbeCacheTtl = Duration(minutes: 2);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wowskill.ru',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
    ),
  );

  final Map<String, Future<_WowskillDetailPage?>> _detailCache =
      <String, Future<_WowskillDetailPage?>>{};
  final Map<String, DateTime> _negativeDetailCache = <String, DateTime>{};
  final Map<String, _TimedValue<bool>> _probeCache =
      <String, _TimedValue<bool>>{};

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
    final normalizedQuery = query.trim();
    final profile = WowVersionProfile.parse(gameVersion);
    if (normalizedQuery.isEmpty || profile.isEmpty) {
      return const <AddonItem>[];
    }

    try {
      final html = await _fetchHtml(
        '/?s=${Uri.encodeQueryComponent(normalizedQuery)}',
        requestContext: requestContext,
      );
      if (html == null || html.isEmpty) {
        return const <AddonItem>[];
      }

      final candidates =
          _parseSearchCandidates(html)
              .where(
                (candidate) => _matchesRequestedVersion(candidate, profile),
              )
              .toList()
            ..sort(
              (a, b) =>
                  _scoreCandidate(
                    b.title,
                    b.url,
                    normalizedQuery,
                    profile,
                  ).compareTo(
                    _scoreCandidate(a.title, a.url, normalizedQuery, profile),
                  ),
            );

      return candidates.take(20).map(_candidateToItem).toList(growable: false);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Wowskill Search Error: $error');
      }
      return const <AddonItem>[];
    }
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
    if (profile.isEmpty) {
      return const <AddonItem>[];
    }

    final candidates = <String, _WowskillCandidate>{};
    final maxCatalogPages = _resolveCatalogPageCount(limit);
    for (final basePath in _buildCatalogPathCandidates(profile)) {
      for (var pageIndex = 1; pageIndex <= maxCatalogPages; pageIndex++) {
        String? html;
        final path = _resolveCatalogPagePath(basePath, pageIndex);
        try {
          html = await _fetchHtml(path, requestContext: requestContext);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Wowskill Catalog Error ($path): $error');
          }
          continue;
        }
        if (html == null || html.isEmpty) {
          continue;
        }

        for (final candidate in _parseCatalogCandidates(html)) {
          candidates.putIfAbsent(candidate.url, () => candidate);
        }

        if (candidates.length >= limit) {
          break;
        }
      }

      if (candidates.length >= limit) {
        break;
      }
    }

    return candidates.values
        .take(limit)
        .map(_candidateToItem)
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

    final detail = await _loadDetailPage(
      item.originalId.toString(),
      requestContext: requestContext,
    );
    if (detail == null) {
      return null;
    }

    final selectedDownload = _selectBestDownload(detail, gameVersion);
    if (selectedDownload == null) {
      return null;
    }

    final resolvedUrl = await _resolveReachableUrl(
      selectedDownload.url,
      requestContext: requestContext,
    );
    if (resolvedUrl == null) {
      return null;
    }

    return (
      url: resolvedUrl,
      fileName: _deriveFileName(
        resolvedUrl,
        item,
        selectedDownload.versionLabel,
      ),
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

    final detail = await _loadDetailPage(
      item.originalId.toString(),
      requestContext: requestContext,
    );
    if (detail == null) {
      return null;
    }

    final selectedDownload = _selectBestDownload(detail, gameVersion);
    if (selectedDownload == null) {
      return null;
    }

    final resolvedUrl = await _resolveReachableUrl(
      selectedDownload.url,
      requestContext: requestContext,
    );
    if (resolvedUrl == null) {
      return null;
    }

    return item.copyWith(
      name: detail.displayName.isEmpty ? item.name : detail.displayName,
      summary: detail.summary.isEmpty ? item.summary : detail.summary,
      thumbnailUrl: detail.thumbnailUrl ?? item.thumbnailUrl,
      screenshotUrls: detail.galleryUrls,
      version: selectedDownload.versionLabel.isEmpty
          ? item.version
          : selectedDownload.versionLabel,
      verifiedDownloadUrl: resolvedUrl,
      verifiedFileName: _deriveFileName(
        resolvedUrl,
        item,
        selectedDownload.versionLabel,
      ),
      identityHints: <String>[
        ...item.identityHints,
        detail.displayName,
        selectedDownload.versionLabel,
      ],
    );
  }

  @visibleForTesting
  bool debugMatchesRequestedVersion({
    required String title,
    required String url,
    required String gameVersion,
  }) {
    return _matchesRequestedVersion(
      _WowskillCandidate(url: url, title: title),
      WowVersionProfile.parse(gameVersion),
    );
  }

  @visibleForTesting
  int debugScoreDownloadEntry({
    required String gameVersion,
    required String detailTitle,
    String detailSummary = '',
    required String url,
    String anchorText = '',
    String contextText = '',
    String versionLabel = '',
  }) {
    return _scoreDownloadEntry(
      _WowskillDownloadEntry(
        url: url,
        anchorText: anchorText,
        contextText: contextText,
        versionLabel: versionLabel,
      ),
      WowVersionProfile.parse(gameVersion),
      _detailVersionSignals(rawTitle: detailTitle, summary: detailSummary),
    );
  }

  Future<_WowskillDetailPage?> _loadDetailPage(
    String url, {
    ProviderRequestContext? requestContext,
  }) {
    _clearExpiredNegativeDetailEntries();
    final negativeExpiresAt = _negativeDetailCache[url];
    if (negativeExpiresAt != null &&
        negativeExpiresAt.isAfter(DateTime.now())) {
      return Future<_WowskillDetailPage?>.value(null);
    }

    final cached = _detailCache[url];
    if (cached != null) {
      return cached;
    }

    final future = _fetchDetailPage(url, requestContext: requestContext).then((
      detail,
    ) {
      if (detail == null) {
        _negativeDetailCache[url] = DateTime.now().add(_negativeDetailCacheTtl);
        _detailCache.remove(url);
      } else {
        _negativeDetailCache.remove(url);
      }
      return detail;
    });

    _detailCache[url] = future;
    return future;
  }

  Future<_WowskillDetailPage?> _fetchDetailPage(
    String url, {
    ProviderRequestContext? requestContext,
  }) async {
    try {
      final html = await _fetchHtml(url, requestContext: requestContext);
      if (html == null || html.isEmpty) {
        return null;
      }

      final title =
          _readMetaContent(html, 'property="og:title"') ??
          _readTagText(html, 'h1') ??
          _readTagText(html, 'title') ??
          '';
      final summary =
          _readMetaContent(html, 'name="description"') ??
          _readMetaContent(html, 'property="og:description"') ??
          '';
      final thumbnailUrl = _readMetaContent(html, 'property="og:image"');
      final downloads = _parseDownloadEntries(html);

      return _WowskillDetailPage(
        displayName: _normalizeAddonTitle(title, url: url),
        rawTitle: _cleanupText(title),
        summary: _cleanupText(summary),
        thumbnailUrl: thumbnailUrl,
        galleryUrls: _parseGalleryUrls(html, thumbnailUrl: thumbnailUrl),
        downloads: downloads,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Wowskill Detail Error ($url): $error');
      }
      return null;
    }
  }

  _WowskillDownloadEntry? _selectBestDownload(
    _WowskillDetailPage detail,
    String gameVersion,
  ) {
    final profile = WowVersionProfile.parse(gameVersion);
    final detailSignals = _detailVersionSignals(
      rawTitle: detail.rawTitle,
      summary: detail.summary,
      displayName: detail.displayName,
    );
    final ranked =
        detail.downloads
            .map(
              (entry) => (
                entry: entry,
                score: _scoreDownloadEntry(entry, profile, detailSignals),
              ),
            )
            .where((candidate) => candidate.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isEmpty) {
      return null;
    }

    return ranked.first.entry;
  }

  int _scoreDownloadEntry(
    _WowskillDownloadEntry entry,
    WowVersionProfile profile,
    Iterable<String> detailSignals,
  ) {
    final entrySignals = _expandVersionSignals(<String>[
      entry.url,
      entry.anchorText,
      entry.contextText,
      entry.versionLabel,
    ]);
    final combinedSignals = <String>[
      ..._expandVersionSignals(detailSignals),
      ...entrySignals,
    ];
    final mergedText = combinedSignals.join(' ').toLowerCase();

    if (profile.containsConflictingVersionMarker(mergedText)) {
      return 0;
    }

    if (_requiresExplicitRetailBranchEvidence(profile) &&
        !profile.hasExplicitRequestedBranchEvidence(combinedSignals)) {
      return 0;
    }

    final score = profile.numericCompatibilityScore(combinedSignals);
    if (score > 0) {
      return score;
    }

    if (_requiresExplicitRetailBranchEvidence(profile)) {
      return 0;
    }

    final hasKnownMarker = profile.containsKnownVersionMarker(mergedText);
    if (!hasKnownMarker && entry.versionLabel.isEmpty) {
      return 12;
    }

    return 0;
  }

  List<_WowskillCandidate> _parseSearchCandidates(String html) {
    final matches = RegExp(
      r'<h2[^>]*class="[^"]*post-title[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final candidates = <String, _WowskillCandidate>{};
    for (final match in matches) {
      final url = _normalizeWowskillUrl(match.group(1));
      final title = _normalizeAddonTitle(match.group(2) ?? '', url: url);
      if (url == null ||
          title.isEmpty ||
          !_looksLikeAddonDetailPage(url, title)) {
        continue;
      }

      candidates.putIfAbsent(
        url,
        () => _WowskillCandidate(url: url, title: title),
      );
    }

    return candidates.values.toList(growable: false);
  }

  List<_WowskillCandidate> _parseCatalogCandidates(String html) {
    final matches = RegExp(
      r'<h2[^>]*class="[^"]*post-title[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final candidates = <String, _WowskillCandidate>{};
    for (final match in matches) {
      final url = _normalizeWowskillUrl(match.group(1));
      final title = _normalizeAddonTitle(match.group(2) ?? '', url: url);
      if (url == null ||
          title.isEmpty ||
          !_looksLikeAddonDetailPage(url, title)) {
        continue;
      }

      candidates.putIfAbsent(
        url,
        () => _WowskillCandidate(url: url, title: title),
      );
    }

    return candidates.values.toList(growable: false);
  }

  List<_WowskillDownloadEntry> _parseDownloadEntries(String html) {
    final matches = RegExp(
      r'(.{0,180})<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    final entries = <_WowskillDownloadEntry>[];
    final seenUrls = <String>{};
    for (final match in matches) {
      final url = _normalizeDownloadUrl(match.group(2));
      if (url == null || !_looksLikeDownloadHref(url) || !seenUrls.add(url)) {
        continue;
      }

      final anchorText = _cleanupText(_stripHtml(match.group(3) ?? ''));
      final contextText = _cleanupText(_stripHtml(match.group(1) ?? ''));
      final versionLabel = _extractVersionLabel(
        '$anchorText $contextText $url',
      );
      entries.add(
        _WowskillDownloadEntry(
          url: url,
          anchorText: anchorText,
          contextText: contextText,
          versionLabel: versionLabel,
        ),
      );
    }

    return entries;
  }

  Future<String?> _fetchHtml(
    String pathOrUrl, {
    ProviderRequestContext? requestContext,
  }) async {
    final uri = Uri.parse(pathOrUrl);
    final requestUri = uri.hasScheme
        ? uri
        : Uri.parse(_dio.options.baseUrl).resolve(pathOrUrl);

    final response = await executeWithRetry<Response<dynamic>>(
      requestContext: requestContext,
      task: (cancelToken, timeout) => _dio.getUri(
        requestUri,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: timeout,
          sendTimeout: timeout,
          validateStatus: (status) => status != null && status < 500,
        ),
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 404) {
      return null;
    }

    final data = response.data;
    if (data is String) {
      return data;
    }
    return null;
  }

  Future<String?> _resolveReachableUrl(
    String url, {
    ProviderRequestContext? requestContext,
  }) async {
    final cachedProbe = _readProbeCache(url);
    if (cachedProbe != null) {
      return cachedProbe ? url : null;
    }

    if (await _urlReachable(url, requestContext: requestContext)) {
      _writeProbeCache(url, true);
      return url;
    }

    _writeProbeCache(url, false);
    return null;
  }

  Future<bool> _urlReachable(
    String url, {
    ProviderRequestContext? requestContext,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    if (!_isExternalDownloadHost(uri)) {
      try {
        final headResponse = await executeWithRetry<Response<dynamic>>(
          requestContext: requestContext,
          task: (cancelToken, timeout) => _dio.headUri(
            uri,
            cancelToken: cancelToken,
            options: Options(
              followRedirects: false,
              validateStatus: (status) => status != null && status < 500,
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
          ),
        );
        final statusCode = headResponse.statusCode ?? 0;
        if (statusCode == 200 || statusCode == 301 || statusCode == 302) {
          return true;
        }
      } catch (_) {
        // Ignore and fallback to GET probe.
      }
    }

    try {
      final getResponse = await executeWithRetry<Response<dynamic>>(
        requestContext: requestContext,
        task: (cancelToken, timeout) => _dio.getUri(
          uri,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            headers: const <String, String>{'Range': 'bytes=0-0'},
            validateStatus: (status) => status != null && status < 500,
            receiveTimeout: timeout,
            sendTimeout: timeout,
          ),
        ),
      );
      final statusCode = getResponse.statusCode ?? 0;
      return statusCode == 200 ||
          statusCode == 206 ||
          statusCode == 301 ||
          statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  AddonItem _candidateToItem(_WowskillCandidate candidate) {
    final sourceSlug = _slugFromUrl(candidate.url);
    return AddonItem(
      id: 'wowskill-$sourceSlug',
      name: _normalizeAddonTitle(candidate.title, url: candidate.url),
      summary: '',
      providerName: providerName,
      originalId: candidate.url,
      sourceSlug: sourceSlug,
      identityHints: <String>[candidate.title, sourceSlug, candidate.url],
      version: 'latest',
    );
  }

  Iterable<String> _buildCatalogPathCandidates(
    WowVersionProfile profile,
  ) sync* {
    final versions = <String>{
      profile.majorMinor,
      if (profile.exactVersion != profile.majorMinor) profile.exactVersion,
    }.where((value) => value.trim().isNotEmpty);

    for (final version in versions) {
      final normalizedVersion = version.replaceAll('.', '-');
      yield '/addony-dlya-wow-$normalizedVersion/';
      final familySlug = _familySlug(profile);
      if (familySlug != null) {
        yield '/addony-dlya-vov-$normalizedVersion-wow-$familySlug/';
      }
    }
  }

  int _resolveCatalogPageCount(int limit) {
    if (limit <= 12) {
      return 1;
    }
    if (limit <= 24) {
      return 2;
    }
    return 3;
  }

  String _resolveCatalogPagePath(String basePath, int pageIndex) {
    if (pageIndex <= 1) {
      return basePath;
    }

    final normalizedBasePath = basePath.endsWith('/') ? basePath : '$basePath/';
    return '${normalizedBasePath}page/$pageIndex/';
  }

  int _scoreCandidate(
    String title,
    String url,
    String query,
    WowVersionProfile profile,
  ) {
    final versionSignals = _expandVersionSignals(<String>[title, url]);
    final mergedSignals = versionSignals.join(' ').toLowerCase();
    if (profile.containsConflictingVersionMarker(mergedSignals)) {
      return 0;
    }

    if (_requiresExplicitRetailBranchEvidence(profile) &&
        !profile.hasExplicitRequestedBranchEvidence(versionSignals)) {
      return 0;
    }

    final normalizedTitle = _normalizeIdentity(title);
    final normalizedQuery = _normalizeIdentity(query);
    final normalizedSlug = _normalizeIdentity(_slugFromUrl(url));

    var score = 0;
    if (normalizedTitle == normalizedQuery ||
        normalizedSlug == normalizedQuery) {
      score += 260;
    } else if (normalizedTitle.startsWith(normalizedQuery) ||
        normalizedSlug.startsWith(normalizedQuery)) {
      score += 180;
    } else if (normalizedTitle.contains(normalizedQuery) ||
        normalizedSlug.contains(normalizedQuery)) {
      score += 110;
    }

    final compatibilityScore = profile.numericCompatibilityScore(
      versionSignals,
    );
    score += compatibilityScore;

    return score;
  }

  bool _matchesRequestedVersion(
    _WowskillCandidate candidate,
    WowVersionProfile profile,
  ) {
    final signals = _expandVersionSignals(<String>[
      candidate.title,
      candidate.url,
    ]);
    final text = signals.join(' ').toLowerCase();
    if (profile.containsConflictingVersionMarker(text)) {
      return false;
    }

    if (_requiresExplicitRetailBranchEvidence(profile)) {
      return profile.hasExplicitRequestedBranchEvidence(signals);
    }

    if (profile.numericCompatibilityScore(signals) > 0) {
      return true;
    }

    return !profile.containsConflictingVersionMarker(text);
  }

  bool _requiresExplicitRetailBranchEvidence(WowVersionProfile profile) {
    return profile.isRetailEra;
  }

  List<String> _detailVersionSignals({
    required String rawTitle,
    required String summary,
    String displayName = '',
  }) {
    return <String>[rawTitle, summary, displayName];
  }

  List<String> _expandVersionSignals(Iterable<String> values) {
    final expanded = <String>[];
    for (final value in values) {
      final normalized = value.replaceAllMapped(
        RegExp(r'(?<=\d)[\-_](?=\d)'),
        (_) => '.',
      );
      expanded.add(value);
      if (normalized != value) {
        expanded.add(normalized);
      }
    }
    return expanded;
  }

  bool _looksLikeAddonDetailPage(String url, String title) {
    final normalizedUrl = url.toLowerCase();
    final normalizedTitle = title.toLowerCase();
    if (!normalizedUrl.startsWith('https://wowskill.ru/')) {
      return false;
    }

    if (normalizedUrl.contains('/search/') ||
        normalizedUrl.contains('/category/') ||
        normalizedUrl.contains('/tag/') ||
        normalizedUrl.contains('/feed/') ||
        normalizedUrl.contains('/addony-dlya-wow') ||
        normalizedUrl.contains('/addony-dlya-vov')) {
      return false;
    }

    return !normalizedTitle.contains('гайд') &&
        !normalizedTitle.contains('макрос') &&
        !normalizedTitle.contains('маунт');
  }

  String _normalizeAddonTitle(String rawTitle, {String? url}) {
    final slug = url == null ? '' : _slugFromUrl(url);
    final originalTitle = _cleanupText(
      _stripHtml(rawTitle),
    ).replaceAll(RegExp(r'[«»"“”]+'), ' ');
    final leadingTitle = _extractLeadingCanonicalTitle(originalTitle);
    if (leadingTitle.isNotEmpty &&
        _countVersionMarkers(leadingTitle) == 0 &&
        !_looksLikePollutedTitle(leadingTitle)) {
      return leadingTitle;
    }

    final hasSeoNoise = _containsSeoNoise(originalTitle);
    final originalVersionCount = _countVersionMarkers(originalTitle);
    var title = originalTitle;
    title = title
        .replaceAll(RegExp(r'^\s*скачать\s+аддон\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*скачать\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*аддон\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bдля\s+вов\b.*$', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\s+(?:для|под)\s+wow\b.*$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(?:для|под)\s+world\s+of\s+warcraft\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s+последней\s+версии.*$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\s*[-:]\s*(?:скачать|download)\b.*$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b\d+\.\d+(?:\.\d+)?(?:\s+и\s+\d+\.\d+(?:\.\d+)?){1,}.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b\d+\.\d+(?:\.\d+)?(?:\s*,\s*\d+\.\d+(?:\.\d+)?){1,}.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[\*\|]+'), ' ')
        .replaceAll(
          RegExp(r'\b\d+\.\d+(?:\.\d+)?\b', caseSensitive: false),
          ' ',
        );
    title = _cleanupText(title);

    final cleanedVersionCount = _countVersionMarkers(title);
    final shouldFallbackToSlug =
        slug.isNotEmpty &&
        (hasSeoNoise ||
            originalVersionCount >= 2 ||
            cleanedVersionCount >= 2 ||
            _looksLikePollutedTitle(title));

    if (shouldFallbackToSlug) {
      return _humanizeSlug(slug);
    }

    if (title.isEmpty || _looksLikePollutedTitle(title)) {
      return _humanizeSlug(slug);
    }

    return title;
  }

  bool _looksLikePollutedTitle(String title) {
    final normalized = title.toLowerCase();
    final versionMatches = _countVersionMarkers(normalized);
    return normalized.contains('скачать') ||
        normalized.contains('аддон') ||
        normalized.contains('для wow') ||
        normalized.contains('для вов') ||
        normalized.contains('world of warcraft') ||
        normalized.contains('последней версии') ||
        normalized.contains('addon for wow') ||
        normalized.contains('download') ||
        normalized.contains('*') ||
        versionMatches >= 2 ||
        normalized.length > 42;
  }

  String _extractLeadingCanonicalTitle(String rawTitle) {
    final title = _cleanupText(
      rawTitle
          .replaceAll(
            RegExp(r'^\s*скачать\s+аддон\s+', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'^\s*скачать\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'^\s*аддон\s+', caseSensitive: false), ''),
    );
    if (title.isEmpty) {
      return '';
    }

    final leading = _cleanupText(
      title
          .split(
            RegExp(
              r'\s*(?:\*|\||—|–)\s*|\bскачать\b|\bdownload\b|\bаддон\b|\baddon\b|\bдля\s+(?:wow|вов|world\s+of\s+warcraft)\b|\bпоследней\s+версии\b|\b\d+\.\d+(?:\.\d+)?\b',
              caseSensitive: false,
            ),
          )
          .first,
    );
    return leading.replaceAll(RegExp(r'[\-:]+$'), '').trim();
  }

  bool _containsSeoNoise(String title) {
    final normalized = title.toLowerCase();
    return normalized.contains('скачать') ||
        normalized.contains('аддон') ||
        normalized.contains('для wow') ||
        normalized.contains('для вов') ||
        normalized.contains('world of warcraft') ||
        normalized.contains('последней версии') ||
        normalized.contains('*') ||
        normalized.contains('download');
  }

  int _countVersionMarkers(String value) {
    return RegExp(
      r'\d+\.\d+(?:\.\d+)?',
      caseSensitive: false,
    ).allMatches(value).length;
  }

  String _humanizeSlug(String slug) {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      return '';
    }

    final tokens = normalizedSlug
        .split(RegExp(r'[-_]+'))
        .where((token) => token.trim().isNotEmpty)
        .map(_humanizeSlugToken)
        .toList(growable: false);

    return tokens.join(' ').trim();
  }

  String _humanizeSlugToken(String token) {
    final lower = token.toLowerCase();
    if (lower.isEmpty) {
      return '';
    }
    if (lower == 'dbm') {
      return 'DBM';
    }
    if (lower == 'ui') {
      return 'UI';
    }
    if (lower == 'wow') {
      return 'WoW';
    }
    if (lower.length <= 3) {
      return lower.toUpperCase();
    }
    if (lower.endsWith('ui') && lower.length > 2) {
      final prefix = lower.substring(0, lower.length - 2);
      return '${_capitalizeToken(prefix)}UI';
    }
    return _capitalizeToken(lower);
  }

  String _capitalizeToken(String token) {
    if (token.isEmpty) {
      return '';
    }

    return '${token[0].toUpperCase()}${token.substring(1)}';
  }

  String? _normalizeWowskillUrl(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    return uri.replace(query: '').toString();
  }

  String? _normalizeDownloadUrl(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final baseUri = Uri.parse(_dio.options.baseUrl);
    return baseUri.resolve(trimmed).toString();
  }

  bool _looksLikeDownloadHref(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.endsWith('.zip')) {
      return true;
    }

    final uri = Uri.tryParse(lowerUrl);
    if (uri == null) {
      return false;
    }

    final isExternalHost = uri.host.isNotEmpty && uri.host != 'wowskill.ru';
    if (!isExternalHost) {
      return false;
    }

    return lowerUrl.contains('/file/') ||
        lowerUrl.contains('/download/') ||
        lowerUrl.contains('download=') ||
        lowerUrl.contains('/releases/download/') ||
        lowerUrl.contains('/uploads/');
  }

  bool _isExternalDownloadHost(Uri uri) {
    return uri.host.isNotEmpty && uri.host != 'wowskill.ru';
  }

  bool? _readProbeCache(String url) {
    final cached = _probeCache[url];
    if (cached == null) {
      return null;
    }

    if (cached.expiresAt.isBefore(DateTime.now())) {
      _probeCache.remove(url);
      return null;
    }

    return cached.value;
  }

  void _writeProbeCache(String url, bool isReachable) {
    _probeCache[url] = _TimedValue<bool>(
      value: isReachable,
      expiresAt: DateTime.now().add(
        isReachable ? _positiveProbeCacheTtl : _negativeProbeCacheTtl,
      ),
    );
  }

  void _clearExpiredNegativeDetailEntries() {
    final now = DateTime.now();
    _negativeDetailCache.removeWhere((_, expiresAt) => expiresAt.isBefore(now));
  }

  String? _readMetaContent(String html, String attributePattern) {
    final match = RegExp(
      '<meta[^>]*$attributePattern[^>]*content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    return match == null ? null : _cleanupText(match.group(1) ?? '');
  }

  String? _readTagText(String html, String tagName) {
    final match = RegExp(
      '<$tagName[^>]*>(.*?)</$tagName>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }

    return _cleanupText(_stripHtml(match.group(1) ?? ''));
  }

  List<String> _parseGalleryUrls(String html, {String? thumbnailUrl}) {
    final urls = <String>{
      if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty) thumbnailUrl,
    };

    final matches = RegExp(
      r'(?:data-lazy-src|data-src|src)="([^"]+)"',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in matches) {
      final normalizedUrl = _normalizeDownloadUrl(match.group(1));
      if (normalizedUrl == null) {
        continue;
      }

      final lowerUrl = normalizedUrl.toLowerCase();
      if (!lowerUrl.contains('/wp-content/uploads/')) {
        continue;
      }
      if (!(lowerUrl.endsWith('.jpg') ||
          lowerUrl.endsWith('.jpeg') ||
          lowerUrl.endsWith('.png') ||
          lowerUrl.endsWith('.webp'))) {
        continue;
      }

      urls.add(normalizedUrl);
      if (urls.length >= 6) {
        break;
      }
    }

    return urls.toList(growable: false);
  }

  String _extractVersionLabel(String value) {
    final matches = RegExp(
      r'\d+\.\d+(?:\.\d+)?[a-z]?',
      caseSensitive: false,
    ).allMatches(value).map((match) => match.group(0)!).toList(growable: false);
    if (matches.isEmpty) {
      return '';
    }

    return matches.last;
  }

  String _deriveFileName(String url, AddonItem item, String versionLabel) {
    final uri = Uri.tryParse(url);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(uri!.pathSegments.last)
        : '';
    if (lastSegment.toLowerCase().endsWith('.zip')) {
      return lastSegment;
    }

    final slug = item.sourceSlug ?? _slugFromUrl(item.originalId.toString());
    if (versionLabel.isNotEmpty) {
      return '$slug-$versionLabel.zip';
    }
    return '$slug.zip';
  }

  String _slugFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return _normalizeIdentity(url);
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return _normalizeIdentity(url);
    }

    return segments.last;
  }

  String _normalizeIdentity(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  String _stripHtml(String value) {
    return value.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _cleanupText(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&#8212;', '—')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#039;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _familySlug(WowVersionProfile profile) {
    return switch (profile.family) {
      WowVersionFamily.shadowlands => 'shadowlands',
      WowVersionFamily.dragonflight => 'dragonflight',
      WowVersionFamily.warWithin => 'the-war-within',
      _ => null,
    };
  }
}

class _WowskillCandidate {
  final String url;
  final String title;

  const _WowskillCandidate({required this.url, required this.title});
}

class _WowskillDownloadEntry {
  final String url;
  final String anchorText;
  final String contextText;
  final String versionLabel;

  const _WowskillDownloadEntry({
    required this.url,
    required this.anchorText,
    required this.contextText,
    required this.versionLabel,
  });
}

class _WowskillDetailPage {
  final String displayName;
  final String rawTitle;
  final String summary;
  final String? thumbnailUrl;
  final List<String> galleryUrls;
  final List<_WowskillDownloadEntry> downloads;

  const _WowskillDetailPage({
    required this.displayName,
    required this.rawTitle,
    required this.summary,
    required this.thumbnailUrl,
    required this.galleryUrls,
    required this.downloads,
  });
}

class _TimedValue<T> {
  final T value;
  final DateTime expiresAt;

  const _TimedValue({required this.value, required this.expiresAt});
}
