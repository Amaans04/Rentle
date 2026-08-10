import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_models.dart';

/// Overridden with a real value in a ProviderScope created once the user is
/// signed in (see main.dart) — nothing reads this before that point.
final apiClientProvider = Provider<ApiClient>((ref) {
  throw StateError('apiClientProvider was read before the signed-in ProviderScope override was applied.');
});

/// Same lifecycle as apiClientProvider — needed directly (not just via the
/// token-getter ApiClient wraps) for Clerk actions that aren't our own API,
/// like creating an organization.
final clerkAuthStateProvider = Provider<ClerkAuthState>((ref) {
  throw StateError('clerkAuthStateProvider was read before the signed-in ProviderScope override was applied.');
});

class MeResponse {
  MeResponse({required this.user, required this.memberships});

  final AppUser user;
  final List<Membership> memberships;

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    memberships: (json['memberships'] as List).map((e) => Membership.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

final meProvider = FutureProvider<MeResponse>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.dio.get('/me');
  return MeResponse.fromJson(response.data['data'] as Map<String, dynamic>);
});

Membership? membershipForOrg(MeResponse me, String orgId) {
  for (final m in me.memberships) {
    if (m.organizationId == orgId) return m;
  }
  return null;
}
