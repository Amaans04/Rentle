import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/api_providers.dart';
import '../features/identity/identity_gate.dart';
import '../features/identity/no_access_screen.dart';
import '../features/identity/register_pg_screen.dart';
import '../features/owner/properties/properties_list_screen.dart';
import '../features/tenant/discover_pg_screen.dart';
import '../features/tenant/tenant_accept_screen.dart';
import '../features/tenant/tenant_home_screen.dart';
import '../features/tenant/join_request_status_screen.dart';

/// Only the handful of routes worth naming (deep-linkable-ish entry points)
/// go through go_router; everything drilled into from there (buildings →
/// floors → rooms → beds, tenant/invoice/complaint detail) is a plain
/// Navigator.push, since none of it needs to be reachable by URL.
///
/// RegisterPgScreen and DiscoverPgScreen are real routes here, not a raw
/// Navigator.push from a caller — both call `context.go(...)` internally
/// once their flow completes, which needs go_router to already know about
/// them (see AuthGate below for the other half of this — a real bug found
/// 2026-08-10/11 involving these same call sites, with a deeper root cause
/// than just this).
///
/// Created exactly once, at module load, and never rebuilt — this instance
/// backs the app's single `MaterialApp.router` for its entire lifetime.
final appRouter = buildAppRouter();

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthGate()),
      GoRoute(path: '/no-access', builder: (context, state) => const NoAccessScreen()),
      GoRoute(path: '/register-pg', builder: (context, state) => const RegisterPgScreen()),
      GoRoute(path: '/discover-pg', builder: (context, state) => const DiscoverPgScreen()),
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

/// The `/` route's content — and, critically, the ONLY place `ClerkAuthBuilder`
/// appears in the app. Its old home was main.dart, wrapping the entire
/// Router+ProviderScope as the whole app's root widget. That was the real
/// root cause of a live bug found 2026-08-10/11: ClerkAuthBuilder swaps its
/// ENTIRE returned subtree between signedInBuilder/signedOutBuilder/builder
/// based on Clerk's current internal auth state, and that state can flicker
/// transiently during any Clerk-internal background operation (a
/// session-token refresh, `createOrganization`, anything routed through
/// Clerk's own `safelyCall`) — even just for a frame. With the Router
/// nested inside that swap, a flicker tore down and rebuilt the entire app
/// shell, discarding the ProviderScope override and crashing whatever page
/// happened to be open with "apiClientProvider was read before the
/// signed-in ProviderScope override was applied" — reproduced on multiple
/// different screens, not tied to one navigation path.
///
/// Scoping ClerkAuthBuilder to just this route's content fixes it
/// structurally: the Router and its ProviderScope override
/// (clerkAuthStateHolderProvider, api_providers.dart) now live ABOVE
/// ClerkAuthBuilder, in main.dart, where nothing Clerk does can touch them.
/// A flicker here just rebuilds this one route's content in place — every
/// other already-pushed page (StaffListScreen, PropertiesListScreen, etc.)
/// is a sibling page in go_router's own Navigator stack, entirely
/// unaffected by what this route re-renders.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // ClerkErrorListener's own docs require a Scaffold ancestor (it shows
    // errors via ScaffoldMessenger.of(context)) — matches the Scaffold this
    // route used to get for free from main.dart's old Scaffold(body: ...)
    // root before that structure moved here.
    return Scaffold(
      body: SafeArea(
        child: ClerkErrorListener(
          child: ClerkAuthBuilder(
            signedInBuilder: (context, authState) => _EstablishAuthState(authState: authState),
            signedOutBuilder: (context, authState) => const ClerkAuthentication(),
          ),
        ),
      ),
    );
  }
}

/// Seeds clerkAuthStateHolderProvider from the ClerkAuthState
/// ClerkAuthBuilder just resolved, then renders IdentityGate — which is
/// what actually reads `apiClientProvider` (via GET /me) to decide where to
/// route next. Set synchronously in initState/didUpdateWidget, not a
/// microtask: it must land before IdentityGate's own initState runs, which
/// happens later in the same build pass (parent initState → parent build →
/// child created → child initState), so a synchronous assignment here is
/// what actually guarantees the ordering.
class _EstablishAuthState extends ConsumerStatefulWidget {
  const _EstablishAuthState({required this.authState});

  final ClerkAuthState authState;

  @override
  ConsumerState<_EstablishAuthState> createState() => _EstablishAuthStateState();
}

class _EstablishAuthStateState extends ConsumerState<_EstablishAuthState> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _EstablishAuthState oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final notifier = ref.read(clerkAuthStateHolderProvider.notifier);
    if (!identical(notifier.state, widget.authState)) {
      notifier.state = widget.authState;
    }
  }

  @override
  Widget build(BuildContext context) => const IdentityGate();
}
