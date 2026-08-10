import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_models.dart';

/// Set exactly once per sign-in, from AuthGate (core/app_router.dart's `/`
/// route) — deliberately a StateProvider set via `.notifier.state = `, NOT
/// a nested ProviderScope override wrapping the Router. The earlier
/// nested-override design put the whole Router+ProviderScope INSIDE
/// ClerkAuthBuilder's conditional signedIn/signedOut widget swap, so any
/// transient auth-state flicker during a Clerk background operation
/// (session-token refresh, org creation, anything routed through Clerk's
/// own `safelyCall`) could tear down and recreate the entire app shell —
/// a real bug found 2026-08-10/11, surfacing unpredictably on whatever
/// page happened to be open as "apiClientProvider was read before the
/// signed-in ProviderScope override was applied". A StateProvider on the
/// app's single root ProviderScope can't have this problem: there's only
/// ever one container for the app's lifetime, and setting its value never
/// touches the widget tree above AuthGate.
final clerkAuthStateHolderProvider = StateProvider<ClerkAuthState?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final authState = ref.watch(clerkAuthStateHolderProvider);
  if (authState == null) {
    throw StateError('apiClientProvider was read before sign-in was established.');
  }
  return ApiClient(
    getToken: () async {
      final token = await authState.sessionToken();
      return token.jwt;
    },
  );
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
