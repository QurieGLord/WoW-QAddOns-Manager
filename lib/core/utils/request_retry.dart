import 'dart:math';

import 'package:dio/dio.dart';
import 'package:wow_qaddons_manager/core/services/provider_request_context.dart';

final Random _retryRandom = Random();

Future<T> executeWithRetry<T>({
  required Future<T> Function(CancelToken? cancelToken, Duration timeout) task,
  ProviderRequestContext? requestContext,
  int maxRetries = 2,
}) async {
  final timeout = requestContext?.timeout ?? const Duration(seconds: 12);

  for (var attempt = 0; ; attempt++) {
    if (requestContext?.isCancelled ?? false) {
      throw DioException.requestCancelled(
        requestOptions: RequestOptions(),
        reason: 'request_cancelled',
      );
    }

    try {
      return await task(requestContext?.cancelToken, timeout);
    } on DioException catch (error) {
      if (!_shouldRetry(error) || attempt >= maxRetries) {
        rethrow;
      }

      final baseDelayMs = 250 * (1 << attempt);
      final jitterMs = _retryRandom.nextInt(120);
      await Future<void>.delayed(
        Duration(milliseconds: baseDelayMs + jitterMs),
      );
    }
  }
}

bool _shouldRetry(DioException error) {
  if (error.type == DioExceptionType.cancel) {
    return false;
  }

  final statusCode = error.response?.statusCode ?? 0;
  return statusCode == 429 || statusCode >= 500;
}
