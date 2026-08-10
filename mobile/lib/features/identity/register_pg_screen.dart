import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/providers/api_providers.dart';

/// Owner self-serve registration: creates a real Clerk organization via the
/// signed-in user's own session (Auth.createOrganization — no new server
/// endpoint needed, this is exactly what the existing Clerk webhook already
/// provisions locally for). Clerk makes the creator an org:admin
/// automatically, which the webhook maps to OrgMemberRole.OWNER.
class RegisterPgScreen extends ConsumerStatefulWidget {
  const RegisterPgScreen({super.key});

  @override
  ConsumerState<RegisterPgScreen> createState() => _RegisterPgScreenState();
}

enum _Step { form, waiting, stillWaiting }

class _RegisterPgScreenState extends ConsumerState<RegisterPgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  _Step _step = _Step.form;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _step = _Step.waiting;
      _error = null;
    });
    try {
      await ref.read(clerkAuthStateHolderProvider)!.createOrganization(name: _name.text.trim());
      await _waitForMembership();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _error = ApiException.from(e).message;
      });
    }
  }

  /// The organization exists in Clerk the moment createOrganization returns,
  /// but our side only learns about it once the Clerk webhook lands and
  /// provisions the local Organization/OrganizationMember rows — which on a
  /// cold Render free-tier instance can genuinely take a couple of minutes,
  /// not just seconds. Poll patiently rather than erroring out.
  Future<void> _waitForMembership() async {
    final api = ref.read(apiClientProvider);
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await api.dio.get('/me');
        final memberships = (res.data['data']['memberships'] as List);
        if (memberships.isNotEmpty) {
          // Deliberately route back to `/` and let IdentityGate re-resolve
          // and pick the destination, rather than computing
          // `/org/$orgId/properties` here directly — this call collapses
          // three stacked pages (`/` -> `/no-access` -> `/register-pg`) into
          // one in a single `.go()`, which surfaced a real bug (2026-08-10,
          // real device): the new page landed outside the signed-in
          // ProviderScope override, throwing "apiClientProvider was read
          // before the signed-in ProviderScope override was applied."
          // IdentityGate's own `_goToOrg` call already does this exact
          // navigation correctly for every staff sign-in, so reusing it
          // sidesteps the bug instead of chasing its exact mechanism.
          if (mounted) context.go('/');
          return;
        }
      } catch (_) {
        // transient — keep polling until the deadline
      }
      if (mounted && _step != _Step.stillWaiting && DateTime.now().isAfter(deadline.subtract(const Duration(minutes: 2)))) {
        setState(() => _step = _Step.stillWaiting);
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    if (mounted) setState(() => _step = _Step.stillWaiting);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register your PG')),
      body: switch (_step) {
        _Step.form => _buildForm(),
        _Step.waiting => _buildWaiting("Setting up your PG…"),
        _Step.stillWaiting => _buildWaiting(
          "Still setting up — this can take a minute or two if the server was asleep. "
          'Hang tight, or check back shortly.',
          showRetry: true,
        ),
      },
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("What's your PG called?"),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'PG name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) => _register(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _register, child: const Text('Register my PG')),
        ],
      ),
    );
  }

  Widget _buildWaiting(String message, {bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (showRetry) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _waitForMembership, child: const Text('Check again')),
            ],
          ],
        ),
      ),
    );
  }
}
