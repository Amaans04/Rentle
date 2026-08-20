import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/providers/api_providers.dart';
import '../../core/models/user_models.dart';
import '../../core/tenant_prefs.dart';
import '../../core/widgets/app_list_card.dart';
import '../../core/widgets/staggered_entrance.dart';

/// First thing shown after Clerk sign-in. Calls GET /me and routes based on
/// what comes back: staff (memberships present) go straight into the owner
/// app (or an org picker if they belong to more than one org); everyone else
/// is checked against a locally-remembered tenant org before falling back to
/// "no access yet". See docs/PROGRESS.md Phase 5 for the reasoning — tenants
/// are never OrganizationMembers, so this can't be answered from `role`.
class IdentityGate extends ConsumerStatefulWidget {
  const IdentityGate({super.key});

  @override
  ConsumerState<IdentityGate> createState() => _IdentityGateState();
}

class _IdentityGateState extends ConsumerState<IdentityGate> {
  bool _loading = true;
  String? _error;
  List<Membership> _pickableMemberships = const [];
  ProviderSubscription<ClerkAuthState?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    if (ref.read(clerkAuthStateHolderProvider) != null) {
      _resolve();
    } else {
      // AuthGate's hand-off (core/app_router.dart's _EstablishAuthState)
      // defers setting clerkAuthStateHolderProvider to a microtask to avoid
      // a real crash (modifying a provider mid-build — found 2026-08-12 on
      // a device with an already-restored Clerk session), so it may not
      // have landed yet the instant this widget mounts. Wait for it instead
      // of assuming it's already there — that assumption was the exact
      // "apiClientProvider read before sign-in was established" bug this
      // hand-off exists to prevent.
      _authStateSubscription = ref.listenManual<ClerkAuthState?>(clerkAuthStateHolderProvider, (previous, next) {
        if (next != null) {
          _authStateSubscription?.close();
          _authStateSubscription = null;
          _resolve();
        }
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.close();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
      _pickableMemberships = const [];
    });

    final api = ref.read(apiClientProvider);
    try {
      final response = await api.dio.get('/me');
      final me = MeResponse.fromJson(response.data['data'] as Map<String, dynamic>);

      if (me.memberships.isNotEmpty) {
        if (me.memberships.length == 1) {
          _goToOrg(me.memberships.first.organizationId);
          return;
        }
        setState(() {
          _loading = false;
          _pickableMemberships = me.memberships;
        });
        return;
      }

      final tenantOrgId = await TenantPrefs.getOrgId();
      if (tenantOrgId != null) {
        try {
          await api.dio.get('/organizations/$tenantOrgId/tenant/me');
          if (mounted) context.go('/tenant/$tenantOrgId/home');
          return;
        } catch (_) {
          await TenantPrefs.clear();
        }
      }

      final pendingJoinOrgId = await TenantPrefs.getPendingJoinOrgId();
      if (pendingJoinOrgId != null) {
        if (mounted) context.go('/tenant/$pendingJoinOrgId/join-request-status');
        return;
      }

      if (mounted) context.go('/no-access');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiException.from(e).message;
      });
    }
  }

  void _goToOrg(String orgId) {
    if (mounted) context.go('/org/$orgId/properties');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _resolve, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    // More than one membership — let them pick which org to manage.
    return Scaffold(
      appBar: AppBar(title: const Text('Choose an organization')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pickableMemberships.length,
        itemBuilder: (context, index) {
          final m = _pickableMemberships[index];
          return StaggeredEntrance(
            index: index,
            child: AppListCard(
              leadingIcon: Icons.apartment,
              title: m.organizationName,
              subtitle: m.role,
              onTap: () => _goToOrg(m.organizationId),
            ),
          );
        },
      ),
    );
  }
}
