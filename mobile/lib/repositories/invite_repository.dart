import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentle/core/network/api_client.dart';
import 'package:rentle/models/invite_model.dart';
import 'package:rentle/repositories/auth_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(apiClient: ref.watch(apiClientProvider));
});

class InviteRepository {
  InviteRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<InviteModel?> checkInvite(String phone) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/invites/check',
      queryParameters: {'phone': phone},
      skipAuth: true,
    );
    if (response.data?['invite'] == null) return null;
    return InviteModel.fromJson(
      Map<String, dynamic>.from(response.data!['invite'] as Map),
    );
  }

  Future<Map<String, dynamic>> acceptInvite(String inviteId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/invites/accept',
      data: {'inviteId': inviteId},
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to accept invite');
    }
    return response.data!;
  }

  Future<void> declineInvite(String inviteId) async {
    await _api.post(
      '/api/invites/decline',
      data: {'inviteId': inviteId},
    );
  }
}
