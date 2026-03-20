abstract class CacheService {
  T? get<T>(String namespace, String key);

  void set<T>(
    String namespace,
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 10),
  });

  Future<Map<String, dynamic>?> getJson(String namespace, String key);

  Future<void> setJson(
    String namespace,
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 10),
  });

  Future<T> coalesce<T>(
    String namespace,
    String key,
    Future<T> Function() loader,
  );

  void invalidate(String namespace, String key);

  void invalidateNamespace(String namespace);
}
