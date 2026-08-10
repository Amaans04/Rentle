import 'package:dio/dio.dart';

/// Turns a DioException (or anything else) into a message worth showing a
/// user, using the server's {success:false, error:{code,message}} envelope
/// when present.
class ApiException implements Exception {
  ApiException(this.message, {this.code});

  final String message;
  final String? code;

  factory ApiException.from(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        return ApiException(err['message']?.toString() ?? 'Something went wrong.', code: err['code']?.toString());
      }
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return ApiException('The server took too long to respond. It may be waking up — try again in a moment.');
      }
      return ApiException(error.message ?? 'Could not reach the server.');
    }
    return ApiException(error.toString());
  }

  @override
  String toString() => message;
}
