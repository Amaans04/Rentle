import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/providers/api_providers.dart';
import '../../core/models/user_models.dart';
import '../../core/tenant_prefs.dart';

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

  @override
  void initState() {
    super.initState();
    _resolve();
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
                const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
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
      body: ListView.separated(
        itemCount: _pickableMemberships.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final m = _pickableMemberships[index];
          return ListTile(
            title: Text(m.organizationName),
            subtitle: Text(m.role),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _goToOrg(m.organizationId),
          );
        },
      ),
    );
  }
}
