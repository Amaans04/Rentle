import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const authTokenKey = 'auth_token';
  static const refreshTokenKey = 'refresh_token';
  static const uidKey = 'uid';

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();

  Future<String?> getAuthToken() => read(authTokenKey);

  Future<void> setAuthToken(String token) => write(authTokenKey, token);

  Future<String?> getRefreshToken() => read(refreshTokenKey);

  Future<void> setRefreshToken(String token) => write(refreshTokenKey, token);

  Future<String?> getUid() => read(uidKey);

  Future<void> setUid(String uid) => write(uidKey, uid);

  Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String uid,
  }) async {
    await Future.wait([
      setAuthToken(token),
      setRefreshToken(refreshToken),
      setUid(uid),
    ]);
  }

  Future<void> clearSession() => clear();
}
