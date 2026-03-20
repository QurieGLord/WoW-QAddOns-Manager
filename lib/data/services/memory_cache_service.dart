import 'package:wow_qaddons_manager/core/services/cache_service.dart';

class MemoryCacheService implements CacheService {
  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  final Map<String, Future<Object?>> _inflight = <String, Future<Object?>>{};

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
    if (value is! T) {
      return null;
    }

    return value as T;
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
    return get<Map<String, dynamic>>(namespace, key);
  }

  @override
  Future<void> setJson(
    String namespace,
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 10),
  }) async {
    set<Map<String, dynamic>>(namespace, key, value, ttl: ttl);
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
    _entries.remove(_buildCacheKey(namespace, key));
  }

  @override
  void invalidateNamespace(String namespace) {
    final prefix = '$namespace:';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  String _buildCacheKey(String namespace, String key) {
    return '$namespace:$key';
  }
}

class _CacheEntry {
  final Object value;
  final DateTime expiresAt;

  const _CacheEntry({required this.value, required this.expiresAt});
}
