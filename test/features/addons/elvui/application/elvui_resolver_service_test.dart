import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_qaddons_manager/domain/models/addon_resolution_classification.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/application/elvui_resolver_service.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/data/elvui_manifest_repository.dart';

void main() {
  late ElvUiResolverService service;

  setUp(() {
    service = ElvUiResolverService(
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
                  'evidence': <String>['exact'],
                },
                <String, Object?>{
                  'id': 'elvui-retail-branch',
                  'flavor': 'retail',
                  'clientFamily': 'retail',
                  'clientVersionMin': '11.1.0',
                  'clientVersionMax': '11.1.9',
                  'packageVersion': '13.99',
                  'packageUrl': 'https://example.com/elvui-11.1.x.zip',
                  'classification': 'branchCompatible',
                  'evidence': <String>['branch'],
                },
                <String, Object?>{
                  'id': 'elvui-vanilla-exact',
                  'flavor': 'vanilla',
                  'clientFamily': 'vanilla',
                  'clientVersionMin': '1.15.8',
                  'clientVersionMax': '1.15.8',
                  'packageVersion': '13.20',
                  'packageUrl': 'https://example.com/elvui-1.15.8.zip',
                  'classification': 'exact',
                  'evidence': <String>['classic'],
                },
              ],
            },
          ),
        }),
      ),
    );
  });

  test('returns exact verified result when manifest has exact entry', () async {
    final result = await service.resolveForClient('11.1.5');

    expect(result.classification, AddonResolutionClassification.exact);
    expect(result.entry?.id, 'elvui-retail-exact');
  });

  test(
    'returns branch-compatible verified result when exact mapping is absent',
    () async {
      final result = await service.resolveForClient('11.1.7');

      expect(
        result.classification,
        AddonResolutionClassification.branchCompatible,
      );
      expect(result.entry?.id, 'elvui-retail-branch');
    },
  );

  test('returns not verified when manifest has no mapping', () async {
    final result = await service.resolveForClient('11.2.0');

    expect(result.classification, AddonResolutionClassification.notVerified);
    expect(result.entry, isNull);
  });

  test('keeps non-retail path working for old classic era versions', () async {
    final result = await service.resolveForClient(
      '1.15.8',
      clientType: ClientType.classic,
    );

    expect(result.classification, AddonResolutionClassification.exact);
    expect(result.entry?.id, 'elvui-vanilla-exact');
  });

  test('recognizes only core ElvUI queries', () {
    expect(service.isElvUiQuery('elvui'), isTrue);
    expect(service.isElvUiQuery('elv ui retail'), isTrue);
    expect(service.isElvUiQuery('elvui 11.1.5'), isTrue);
    expect(service.isElvUiQuery('elvui windtools'), isFalse);
  });
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
