import 'package:dio/dio.dart';

import '../../app/auth_logout.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_envelope.dart';
import 'api_exception.dart';

const _retryKey = '_auth_retry';

/// 401 sonrası bir kez `/auth/refresh` dener; başarısızsa tokenları siler ve [fireAuthLogout] çağırır.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.storage, required this.dio});

  final TokenStorage storage;
  final Dio dio;

  Dio? _refreshDio;

  Dio get refreshDio {
    return _refreshDio ??= Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_retryKey] == true) {
      return handler.next(options);
    }
    final token = await storage.readAccess();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response?.statusCode != 401) {
      return handler.next(err);
    }
    final path = err.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh')) {
      return handler.next(err);
    }
    if (err.requestOptions.extra[_retryKey] == true) {
      await storage.clear();
      fireAuthLogout();
      return handler.next(err);
    }
    final refresh = await storage.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      await storage.clear();
      fireAuthLogout();
      return handler.next(err);
    }
    try {
      final r = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = ApiEnvelope.parseData<Map<String, dynamic>>(
        r.data,
        (j) => Map<String, dynamic>.from(j! as Map),
      );
      final access = data['access_token'] as String?;
      if (access == null || access.isEmpty) {
        throw ApiException(message: 'Yenileme yanıtı geçersiz');
      }
      await storage.writeAccess(access);
      final req = err.requestOptions;
      req.headers['Authorization'] = 'Bearer $access';
      req.extra[_retryKey] = true;
      final clone = await dio.fetch(req);
      return handler.resolve(clone);
    } catch (_) {
      await storage.clear();
      fireAuthLogout();
      return handler.reject(err);
    }
  }
}
