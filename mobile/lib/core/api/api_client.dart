import 'package:dio/dio.dart';
import '../config/env.dart';

/// Thin Dio wrapper for our own server/ API — decoupled from ClerkAuthState
/// directly (takes a token-getter function instead) so this class doesn't
/// need to know anything about the auth SDK's shape, just how to get a
/// bearer token when it needs one.
class ApiClient {
  ApiClient({required Future<String?> Function() getToken}) : _getToken = getToken {
    dio = Dio(
      BaseOptions(baseUrl: Env.apiBaseUrl, connectTimeout: const Duration(seconds: 15)),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio dio;
  final Future<String?> Function() _getToken;
}
