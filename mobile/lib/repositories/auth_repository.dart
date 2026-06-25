import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentle/core/constants/env.dart';
import 'package:rentle/core/network/api_client.dart';
import 'package:rentle/core/storage/secure_storage.dart';
import 'package:rentle/models/user_model.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(secureStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureStorage storage,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _api = apiClient,
        _storage = storage,
        _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final ApiClient _api;
  final SecureStorage _storage;
  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool get _isFirebaseReady =>
      Env.isFirebaseConfigured && Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth {
    if (!_isFirebaseReady) {
      throw StateError(
        'Firebase is not configured. Add FIREBASE_API_KEY, '
        'FIREBASE_MESSAGING_SENDER_ID, and FIREBASE_APP_ID to mobile/.env',
      );
    }
    return _firebaseAuth ?? FirebaseAuth.instance;
  }

  Future<void> sendOtp({required String phone, required String role}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/auth/send-otp',
      data: {'phone': phone, 'role': role},
      skipAuth: true,
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to send OTP');
    }
  }

  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/auth/verify-otp',
      data: {'phone': phone, 'otp': otp, 'role': role},
      skipAuth: true,
    );
    if (response.data == null || response.data!['token'] == null) {
      throw Exception(response.data?['error'] ?? 'Verification failed');
    }
    final result = AuthResult.fromJson(response.data!);
    await _storage.saveSession(
      token: result.token,
      refreshToken: result.refreshToken,
      uid: result.uid,
    );
    return result;
  }

  Future<AuthResult> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to get Firebase ID token');
    }

    final response = await _api.post<Map<String, dynamic>>(
      '/api/auth/google-session',
      data: {'idToken': idToken},
      skipAuth: true,
    );
    if (response.data == null || response.data!['token'] == null) {
      throw Exception(response.data?['error'] ?? 'Google session failed');
    }
    final result = AuthResult.fromJson(response.data!);
    await _storage.saveSession(
      token: result.token,
      refreshToken: result.refreshToken,
      uid: result.uid,
    );
    return result;
  }

  Future<void> saveTokensFromResponse(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (token == null || refreshToken == null) return;
    final uid = await _storage.getUid() ?? '';
    await _storage.saveSession(
      token: token,
      refreshToken: refreshToken,
      uid: uid,
    );
  }

  Future<void> refreshSession() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    final response = await _api.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
      skipAuth: true,
    );

    final newToken = response.data?['token'] as String?;
    final newRefresh = response.data?['refreshToken'] as String?;
    if (newToken == null || newRefresh == null) {
      throw Exception('Failed to refresh session');
    }

    final uid = await _storage.getUid();
    await _storage.saveSession(
      token: newToken,
      refreshToken: newRefresh,
      uid: uid ?? '',
    );
  }

  Future<MeResponse> getMe() async {
    final response = await _api.get<Map<String, dynamic>>('/api/auth/me');
    if (response.data == null) {
      throw Exception('Failed to load profile');
    }
    return MeResponse.fromJson(response.data!);
  }

  Future<void> logout() async {
    try {
      await _api.post<Map<String, dynamic>>('/api/auth/logout');
    } catch (_) {}
    if (_isFirebaseReady) {
      await _auth.signOut();
    }
    await _googleSignIn.signOut();
    await _storage.clearSession();
  }

  Future<String?> getStoredToken() => _storage.getAuthToken();

  Future<String?> getStoredUid() => _storage.getUid();

  String sanitizePhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (cleaned.startsWith('+91')) cleaned = cleaned.substring(3);
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  bool isValidPhone(String phone) {
    final cleaned = sanitizePhone(phone);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }
}
