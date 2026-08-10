import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/invite_code.dart';
import '../../core/providers/api_providers.dart';
import '../../core/tenant_prefs.dart';
import '../../core/widgets/async_value_view.dart';

class TenantAcceptScreen extends ConsumerStatefulWidget {
  const TenantAcceptScreen({super.key});

  @override
  ConsumerState<TenantAcceptScreen> createState() => _TenantAcceptScreenState();
}

class _TenantAcceptScreenState extends ConsumerState<TenantAcceptScreen> {
  final _code = TextEditingController();
  bool _saving = false;

  Future<void> _accept() async {
    final invite = InviteCode.tryDecode(_code.text);
    if (invite == null) {
      showErrorSnackBar(
        context,
        'That code doesn\'t look right — check it was copied in full.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/organizations/${invite.organizationId}/tenant/onboarding/accept',
        data: {'token': invite.token},
      );
      await TenantPrefs.setOrgId(invite.organizationId);
      // Route through `/` and let IdentityGate re-resolve — see the same
      // fix (and its full reasoning) in register_pg_screen.dart and
      // discover_pg_screen.dart. This screen has the identical multi-page
      // stack shape (`/` -> `/no-access` -> `/tenant/accept`), so it's at
      // the same risk even without a confirmed repro here.
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Accept invite')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste the invite code your PG owner shared with you.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste invite code here',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _accept,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Accept invite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
