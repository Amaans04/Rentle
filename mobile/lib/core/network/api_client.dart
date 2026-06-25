import 'package:dio/dio.dart';
import 'package:rentle/core/constants/env.dart';
import 'package:rentle/core/storage/secure_storage.dart';

class ApiClient {
  ApiClient({SecureStorage? storage, Dio? dio})
      : _storage = storage ?? SecureStorage(),
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final SecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  Dio get dio => _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth) {
      final token = await _storage.getAuthToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final isRetried = err.requestOptions.extra['retried'] == true;
    final skipAuth = err.requestOptions.extra['skipAuth'] == true;

    if (statusCode == 403 && !isRetried && !skipAuth) {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final refreshResponse = await _dio.post<Map<String, dynamic>>(
            '/api/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(extra: {'skipAuth': true}),
          );

          final newToken = refreshResponse.data?['token'] as String?;
          final newRefresh = refreshResponse.data?['refreshToken'] as String?;
          if (newToken != null) {
            await _storage.setAuthToken(newToken);
            if (newRefresh != null) {
              await _storage.setRefreshToken(newRefresh);
            }

            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            retryOptions.extra['retried'] = true;
            final response = await _dio.fetch<dynamic>(retryOptions);
            return handler.resolve(response);
          }
        }
      } catch (_) {
        // Fall through to original error
      }
    }

    if (statusCode != 401 || skipAuth || isRetried) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _storage.clearSession();
        return handler.next(err);
      }

      final refreshResponse = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final newToken = refreshResponse.data?['token'] as String?;
      final newRefresh = refreshResponse.data?['refreshToken'] as String?;
      if (newToken == null) {
        await _storage.clearSession();
        return handler.next(err);
      }

      await _storage.setAuthToken(newToken);
      if (newRefresh != null) {
        await _storage.setRefreshToken(newRefresh);
      }

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      retryOptions.extra['retried'] = true;

      final response = await _dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } catch (_) {
      await _storage.clearSession();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool skipAuth = false,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    bool skipAuth = false,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}
