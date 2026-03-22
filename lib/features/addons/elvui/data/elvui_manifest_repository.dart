import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wow_qaddons_manager/features/addons/elvui/domain/elvui_manifest_entry.dart';

class ElvUiManifestRepository {
  static const String defaultAssetPath = 'assets/manifests/elvui_manifest.json';

  final AssetBundle _assetBundle;
  final String _assetPath;

  Future<List<ElvUiManifestEntry>>? _cachedEntries;

  ElvUiManifestRepository({
    AssetBundle? assetBundle,
    String assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _assetPath = assetPath;

  Future<List<ElvUiManifestEntry>> loadEntries() {
    final cachedEntries = _cachedEntries;
    if (cachedEntries != null) {
      return cachedEntries;
    }

    final future = _loadEntries();
    _cachedEntries = future;
    return future;
  }

  Future<List<ElvUiManifestEntry>> _loadEntries() async {
    final raw = await _assetBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const <ElvUiManifestEntry>[];
    }

    final entries = decoded['entries'];
    if (entries is! List) {
      return const <ElvUiManifestEntry>[];
    }

    return entries
        .whereType<Map>()
        .map(
          (entry) =>
              ElvUiManifestEntry.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((entry) => entry.id.trim().isNotEmpty)
        .toList(growable: false);
  }
}
