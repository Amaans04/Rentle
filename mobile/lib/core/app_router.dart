import 'package:go_router/go_router.dart';
import '../features/identity/identity_gate.dart';
import '../features/identity/no_access_screen.dart';
import '../features/owner/properties/properties_list_screen.dart';
import '../features/tenant/tenant_accept_screen.dart';
import '../features/tenant/tenant_home_screen.dart';
import '../features/tenant/join_request_status_screen.dart';

/// Only the handful of routes worth naming (deep-linkable-ish entry points)
/// go through go_router; everything drilled into from there (buildings →
/// floors → rooms → beds, tenant/invoice/complaint detail) is a plain
/// Navigator.push, since none of it needs to be reachable by URL.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const IdentityGate()),
      GoRoute(path: '/no-access', builder: (context, state) => const NoAccessScreen()),
      GoRoute(path: '/tenant/accept', builder: (context, state) => const TenantAcceptScreen()),
      GoRoute(
        path: '/tenant/:orgId/home',
        builder: (context, state) => TenantHomeScreen(orgId: state.pathParameters['orgId']!),
      ),
      GoRoute(
        path: '/tenant/:orgId/join-request-status',
        builder: (context, state) => JoinRequestStatusScreen(orgId: state.pathParameters['orgId']!),
      ),
      GoRoute(
        path: '/org/:orgId/properties',
        builder: (context, state) => PropertiesListScreen(orgId: state.pathParameters['orgId']!),
      ),
    ],
  );
}
