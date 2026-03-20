import 'package:dio/dio.dart';

class CachePolicy {
  final bool readMemory;
  final bool writeMemory;
  final bool readDisk;
  final bool writeDisk;

  const CachePolicy({
    required this.readMemory,
    required this.writeMemory,
    required this.readDisk,
    required this.writeDisk,
  });

  static const CachePolicy preferCache = CachePolicy(
    readMemory: true,
    writeMemory: true,
    readDisk: true,
    writeDisk: true,
  );

  static const CachePolicy refresh = CachePolicy(
    readMemory: false,
    writeMemory: true,
    readDisk: false,
    writeDisk: true,
  );

  static const CachePolicy networkOnly = CachePolicy(
    readMemory: false,
    writeMemory: false,
    readDisk: false,
    writeDisk: false,
  );
}

class ProviderRequestContext {
  final String traceId;
  final CancelToken cancelToken;
  final CachePolicy cachePolicy;
  final Duration timeout;
  final DateTime startedAt;
  final DateTime deadline;

  ProviderRequestContext({
    required this.traceId,
    CancelToken? cancelToken,
    this.cachePolicy = CachePolicy.preferCache,
    Duration? timeout,
    DateTime? startedAt,
  }) : cancelToken = cancelToken ?? CancelToken(),
       timeout = timeout ?? const Duration(seconds: 12),
       startedAt = startedAt ?? DateTime.now(),
       deadline = (startedAt ?? DateTime.now()).add(
         timeout ?? const Duration(seconds: 12),
       );

  bool get isCancelled =>
      cancelToken.isCancelled || DateTime.now().isAfter(deadline);

  void cancel([String? reason]) {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel(reason ?? 'request_cancelled');
    }
  }

  ProviderRequestContext copyWith({
    CachePolicy? cachePolicy,
    Duration? timeout,
    CancelToken? cancelToken,
    String? traceId,
  }) {
    return ProviderRequestContext(
      traceId: traceId ?? this.traceId,
      cancelToken: cancelToken ?? this.cancelToken,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      timeout: timeout ?? this.timeout,
      startedAt: startedAt,
    );
  }
}
