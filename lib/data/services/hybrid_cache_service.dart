import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wow_qaddons_manager/core/services/cache_service.dart';

class HybridCacheService implements CacheService {
  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  final Map<String, Future<Object?>> _inflight = <String, Future<Object?>>{};

  Directory? _cacheDirectory;

  @override
  T? get<T>(String namespace, String key) {
    final cacheKey = _buildCacheKey(namespace, key);
    final entry = _entries[cacheKey];
    if (entry == null) {
      return null;
    }

    if (entry.expiresAt.isBefore(DateTime.now())) {
      _entries.remove(cacheKey);
      return null;
    }

    final value = entry.value;
    return value is T ? value as T : null;
  }

  @override
  void set<T>(
    String namespace,
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 10),
  }) {
    _entries[_buildCacheKey(namespace, key)] = _CacheEntry(
      value: value as Object,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  @override
  Future<Map<String, dynamic>?> getJson(String namespace, String key) async {
    final memoryValue = get<Map<String, dynamic>>(namespace, key);
    if (memoryValue != null) {
      return memoryValue;
    }

    final file = await _resolveCacheFile(namespace, key);
    if (!await file.exists()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await file.delete();
        return null;
      }

      final expiresAtRaw = decoded['expiresAt'];
      final payload = decoded['payload'];
      if (expiresAtRaw is! String || payload is! Map) {
        await file.delete();
        return null;
      }

      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
        await file.delete();
        return null;
      }

      final mapPayload = payload.map(
        (mapKey, value) => MapEntry(mapKey.toString(), value),
      );
      set<Map<String, dynamic>>(
        namespace,
        key,
        mapPayload,
        ttl: expiresAt.difference(DateTime.now()),
      );
      return mapPayload;
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }
  }

  @override
  Future<void> setJson(
    String namespace,
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 10),
  }) async {
    set<Map<String, dynamic>>(namespace, key, value, ttl: ttl);

    final file = await _resolveCacheFile(namespace, key);
    await file.parent.create(recursive: true);
    final expiresAt = DateTime.now().add(ttl).toIso8601String();
    await file.writeAsString(
      jsonEncode(<String, dynamic>{'expiresAt': expiresAt, 'payload': value}),
    );
  }

  @override
  Future<T> coalesce<T>(
    String namespace,
    String key,
    Future<T> Function() loader,
  ) {
    final cacheKey = _buildCacheKey(namespace, key);
    final existing = _inflight[cacheKey];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    final future = loader();
    _inflight[cacheKey] = future;
    return future.whenComplete(() => _inflight.remove(cacheKey));
  }

  @override
  void invalidate(String namespace, String key) {
    final cacheKey = _buildCacheKey(namespace, key);
    _entries.remove(cacheKey);
    _resolveCacheFile(namespace, key).then((file) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
  }

  @override
  void invalidateNamespace(String namespace) {
    final prefix = '$namespace:';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
    _resolveNamespaceDirectory(namespace).then((directory) {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });
  }

  String _buildCacheKey(String namespace, String key) {
    return '$namespace:$key';
  }

  Future<Directory> _resolveCacheDirectory() async {
    final directory = _cacheDirectory;
    if (directory != null) {
      return directory;
    }

    final baseDirectory = await getApplicationSupportDirectory();
    final cacheDirectory = Directory(p.join(baseDirectory.path, 'cache'));
    await cacheDirectory.create(recursive: true);
    _cacheDirectory = cacheDirectory;
    return cacheDirectory;
  }

  Future<Directory> _resolveNamespaceDirectory(String namespace) async {
    final root = await _resolveCacheDirectory();
    return Directory(p.join(root.path, namespace));
  }

  Future<File> _resolveCacheFile(String namespace, String key) async {
    final namespaceDirectory = await _resolveNamespaceDirectory(namespace);
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return File(p.join(namespaceDirectory.path, '$safeKey.json'));
  }
}

class _CacheEntry {
  final Object value;
  final DateTime expiresAt;

  const _CacheEntry({required this.value, required this.expiresAt});
}
