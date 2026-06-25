import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/router/auth_navigation.dart';

class OwnerAuthScreen extends ConsumerStatefulWidget {
  const OwnerAuthScreen({super.key});

  @override
  ConsumerState<OwnerAuthScreen> createState() => _OwnerAuthScreenState();
}

class _OwnerAuthScreenState extends ConsumerState<OwnerAuthScreen> {
  bool _loading = false;

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authStateProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      AuthNavigation.navigateAfterAuth(
        context,
        role: result.role ?? UserRoleValues.owner,
        isNewUser: result.isNewUser,
        pgId: result.pgId,
        hasInvite: result.hasInvite,
        inviteId: result.inviteId,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RentleAppBar(title: 'Owner Login'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Owner',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: RentleColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How would you like to continue?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RentleColors.charcoal.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              PressableCard(
                onTap: _loading ? null : _googleSignIn,
                child: Row(
                  children: [
                    const Icon(Icons.g_mobiledata_rounded,
                        size: 36, color: RentleColors.trustBlue),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_loading) ...[
                      const Spacer(),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PressableCard(
                onTap: () => context.push(
                  '/auth/phone?role=${UserRoleValues.owner}',
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded, color: RentleColors.coral),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Phone Number',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: GoogleFonts.inter(
                        color: RentleColors.charcoal.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const Spacer(),
              Center(
                child: Text(
                  'New to Rentle? Sign up with either option above',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: RentleColors.charcoal.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
