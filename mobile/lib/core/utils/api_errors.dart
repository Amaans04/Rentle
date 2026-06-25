import 'package:dio/dio.dart';
import 'package:rentle/core/constants/env.dart';

String friendlyApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach the server at ${Env.apiBaseUrl}.\n\n'
          '• Run the server: cd server && npm run dev\n'
          '• Phone and laptop must be on the same Wi‑Fi\n'
          '• On iPhone: Settings → Privacy → Local Network → enable Rentle\n'
          '• Update API_BASE_URL in mobile/.env if your laptop IP changed';
    }

    final code = error.response?.statusCode;
    if (code == 403) {
      return 'You do not have permission. Try logging out and back in.';
    }
    if (code == 500) {
      return 'Server error. Pull to refresh or try again in a moment.';
    }
    return error.message ?? 'Something went wrong';
  }
  return error.toString();
}
