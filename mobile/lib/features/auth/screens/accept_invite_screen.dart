import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';
import 'package:rentle/repositories/invite_repository.dart';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({
    super.key,
    required this.inviteId,
    required this.role,
  });

  final String inviteId;
  final String role;

  @override
  ConsumerState<AcceptInviteScreen> createState() =>
      _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  bool _loading = false;
  bool _declining = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final result =
          await ref.read(inviteRepositoryProvider).acceptInvite(widget.inviteId);
      await ref.read(authRepositoryProvider).saveTokensFromResponse(result);
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      final role = result['role'] as String? ?? widget.role;
      switch (role) {
        case UserRoleValues.owner:
          context.go('/owner/dashboard');
        case UserRoleValues.manager:
          context.go('/manager/dashboard');
        case UserRoleValues.tenant:
          context.go('/tenant/dashboard');
        default:
          context.go('/welcome');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    try {
      await ref.read(inviteRepositoryProvider).declineInvite(widget.inviteId);
      if (!mounted) return;
      context.go('/waiting?role=${widget.role}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const RentleAppBar(title: 'You Have an Invite!'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.pg?.name ?? 'Property Invite',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (me?.pg?.address != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        me!.pg!.address,
                        style: GoogleFonts.inter(
                          color: RentleColors.charcoal.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _row('Role', widget.role == 'tenant' ? 'Tenant' : 'Manager'),
                    if (widget.inviteId.isNotEmpty)
                      _row('Invite ID', widget.inviteId),
                    if (me?.user.phone.isNotEmpty == true)
                      _row('Your Phone', '+91 ${me!.user.phone}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            RentleButton(
              label: 'Accept & Join',
              color: RentleColors.teal,
              loading: _loading,
              onPressed: _accept,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _declining ? null : _decline,
              child: Text(
                'Decline',
                style: GoogleFonts.inter(color: RentleColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter())),
        ],
      ),
    );
  }
}
