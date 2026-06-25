import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, MeResponse?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<MeResponse?> {
  @override
  Future<MeResponse?> build() async {
    final token = await ref.read(authRepositoryProvider).getStoredToken();
    if (token == null || token.isEmpty) return null;
    try {
      return await ref.read(authRepositoryProvider).getMe();
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(authRepositoryProvider).getMe();
    });
  }

  Future<void> refreshSession() async {
    await ref.read(authRepositoryProvider).refreshSession();
    await refresh();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final result = await ref.read(authRepositoryProvider).verifyOtp(
          phone: phone,
          otp: otp,
          role: role,
        );
    await refresh();
    return result;
  }

  Future<AuthResult> signInWithGoogle() async {
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    await refresh();
    return result;
  }
}
