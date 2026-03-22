import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_qaddons_manager/core/services/cache_service.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';
import 'package:wow_qaddons_manager/core/services/search_telemetry_service.dart';
import 'package:wow_qaddons_manager/domain/models/addon_item.dart';
import 'package:wow_qaddons_manager/domain/models/addon_resolution_classification.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/application/elvui_resolver_service.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/data/elvui_manifest_repository.dart';
import 'package:wow_qaddons_manager/features/addons/search/data/search_repository.dart';
import 'package:wow_qaddons_manager/features/addons/shared/application/services/provider_services.dart';

void main() {
  late SearchRepository repository;
  late _FakeCurseForgeService curseForgeService;
  late _FakeGitHubService gitHubService;
  late _FakeWowskillService wowskillService;

  setUp(() {
    curseForgeService = _FakeCurseForgeService();
    gitHubService = _FakeGitHubService();
    wowskillService = _FakeWowskillService();

    final elvUiResolver = ElvUiResolverService(
      ElvUiManifestRepository(
        assetBundle: _StringAssetBundle(<String, String>{
          ElvUiManifestRepository.defaultAssetPath: jsonEncode(
            <String, Object?>{
              'entries': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'elvui-retail-exact',
                  'flavor': 'retail',
                  'clientFamily': 'retail',
                  'clientVersionMin': '11.1.5',
                  'clientVersionMax': '11.1.5',
                  'packageVersion': '14.00',
                  'packageUrl': 'https://example.com/elvui-11.1.5.zip',
                  'classification': 'exact',
                },
              ],
            },
          ),
        }),
      ),
    );

    repository = SearchRepository(
      curseForgeService,
      gitHubService,
      wowskillService,
      elvUiResolver,
      _MemoryCacheService(),
      SearchTelemetryService(),
    );
  });

  test(
    'injects manifest-backed ElvUI result and suppresses generic core items',
    () async {
      wowskillService.searchResults = <AddonItem>[
        AddonItem(
          id: 'wowskill-elvui',
          name: 'ElvUI',
          summary: 'Generic HTML result',
          providerName: 'Wowskill',
          originalId: 'https://wowskill.ru/elvui/',
          sourceSlug: 'elvui',
          identityHints: const <String>['elvui'],
        ),
        AddonItem(
          id: 'wowskill-windtools',
          name: 'ElvUI WindTools',
          summary: 'Plugin result',
          providerName: 'Wowskill',
          originalId: 'https://wowskill.ru/elvui-windtools/',
          sourceSlug: 'elvui-windtools',
          identityHints: const <String>['elvui-windtools'],
        ),
      ];

      final results = await repository.loadSearchCandidates(
        'elvui',
        '11.1.5',
        requestContext: ProviderRequestContext(traceId: 'search:elvui'),
      );

      expect(results, isNotEmpty);
      expect(
        results.first.item.providerName,
        ElvUiResolverService.providerName,
      );
      expect(
        results.first.item.resolutionClassification,
        AddonResolutionClassification.exact,
      );
      expect(
        results.any(
          (candidate) =>
              candidate.item.providerName == 'Wowskill' &&
              candidate.item.name == 'ElvUI',
        ),
        isFalse,
      );
      expect(
        results.any((candidate) => candidate.item.name == 'ElvUI WindTools'),
        isTrue,
      );
    },
  );

  test(
    'returns explicit not-verified ElvUI state when manifest has no match',
    () async {
      wowskillService.searchResults = <AddonItem>[
        AddonItem(
          id: 'wowskill-elvui',
          name: 'ElvUI',
          summary: 'Generic HTML result',
          providerName: 'Wowskill',
          originalId: 'https://wowskill.ru/elvui/',
          sourceSlug: 'elvui',
          identityHints: const <String>['elvui'],
        ),
      ];

      final results = await repository.loadSearchCandidates(
        'elv ui retail',
        '11.2.0',
        requestContext: ProviderRequestContext(traceId: 'search:elvui-miss'),
      );

      expect(results, isNotEmpty);
      expect(
        results.first.item.providerName,
        ElvUiResolverService.providerName,
      );
      expect(
        results.first.item.resolutionClassification,
        AddonResolutionClassification.notVerified,
      );
      expect(results.first.item.hasVerifiedPayload, isFalse);
    },
  );

  test('leaves non-ElvUI queries on the generic search path', () async {
    curseForgeService.searchResults = <AddonItem>[
      AddonItem(
        id: 'cf-details',
        name: 'Details!',
        summary: 'Damage meter',
        providerName: 'CurseForge',
        originalId: 1,
        sourceSlug: 'details',
        identityHints: const <String>['details'],
      ),
    ];

    final results = await repository.loadSearchCandidates(
      'details',
      '11.1.5',
      requestContext: ProviderRequestContext(traceId: 'search:details'),
    );

    expect(results, hasLength(1));
    expect(results.first.item.providerName, 'CurseForge');
    expect(
      results.first.item.resolutionClassification,
      AddonResolutionClassification.standard,
    );
  });
}

class _MemoryCacheService implements CacheService {
  final Map<String, Object?> _memory = <String, Object?>{};
  final Map<String, Map<String, dynamic>> _json =
      <String, Map<String, dynamic>>{};

  String _key(String namespace, String key) => '$namespace::$key';

  @override
  Future<T> coalesce<T>(
    String namespace,
    String key,
    Future<T> Function() loader,
  ) {
    return loader();
  }

  @override
  T? get<T>(String namespace, String key) {
    return _memory[_key(namespace, key)] as T?;
  }

  @override
  Future<Map<String, dynamic>?> getJson(String namespace, String key) async {
    return _json[_key(namespace, key)];
  }

  @override
  void invalidate(String namespace, String key) {
    _memory.remove(_key(namespace, key));
    _json.remove(_key(namespace, key));
  }

  @override
  void invalidateNamespace(String namespace) {
    final prefix = '$namespace::';
    _memory.removeWhere((key, value) => key.startsWith(prefix));
    _json.removeWhere((key, value) => key.startsWith(prefix));
  }

  @override
  void set<T>(
    String namespace,
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 10),
  }) {
    _memory[_key(namespace, key)] = value;
  }

  @override
  Future<void> setJson(
    String namespace,
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 10),
  }) async {
    _json[_key(namespace, key)] = value;
  }
}

class _FakeCurseForgeService implements CurseForgeService {
  List<AddonItem> searchResults = const <AddonItem>[];

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return searchResults;
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  }) async {
    return const <AddonItem>[];
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }

  @override
  Future<({String fileName, String url})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }
}

class _FakeGitHubService implements GitHubService {
  List<AddonItem> searchResults = const <AddonItem>[];

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return searchResults;
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }

  @override
  Future<({String fileName, String url})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }
}

class _FakeWowskillService implements WowskillService {
  List<AddonItem> searchResults = const <AddonItem>[];

  @override
  Future<List<AddonItem>> search(
    String query,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return searchResults;
  }

  @override
  Future<List<AddonItem>> fetchPopularAddons(
    String gameVersion, {
    int limit = 50,
    ProviderRequestContext? requestContext,
  }) async {
    return const <AddonItem>[];
  }

  @override
  Future<AddonItem?> verifyCandidate(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }

  @override
  Future<({String fileName, String url})?> getDownloadUrl(
    AddonItem item,
    String gameVersion, {
    ProviderRequestContext? requestContext,
  }) async {
    return null;
  }
}

class _StringAssetBundle extends CachingAssetBundle {
  final Map<String, String> _assets;

  _StringAssetBundle(this._assets);

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing asset: $key');
    }

    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing asset: $key');
    }
    return value;
  }
}
