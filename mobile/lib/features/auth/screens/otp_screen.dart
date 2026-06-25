import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/router/auth_navigation.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.role,
  });

  final String phone;
  final String role;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  bool _loading = false;
  bool _hasError = false;
  String _otp = '';

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final result = await ref.read(authStateProvider.notifier).verifyOtp(
            phone: widget.phone,
            otp: _otp,
            role: widget.role,
          );
      if (!mounted) return;
      AuthNavigation.navigateAfterAuth(
        context,
        role: result.role ?? widget.role,
        isNewUser: result.isNewUser,
        pgId: result.pgId,
        hasInvite: result.hasInvite,
        inviteId: result.inviteId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
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
      appBar: const RentleAppBar(title: 'Verify OTP'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FadeSlideIn(
          child: Column(
            children: [
              Text(
                'Verify your number',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: RentleColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+91${widget.phone}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RentleColors.charcoal.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              OtpBox(
                hasError: _hasError,
                onChanged: (v) => setState(() => _otp = v),
                onCompleted: (v) {
                  setState(() => _otp = v);
                  _verify();
                },
              ),
              const SizedBox(height: 24),
              RentleButton(
                label: 'Verify',
                loading: _loading,
                enabled: _otp.length == 6,
                onPressed: _verify,
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('OTP sent!')),
                  );
                },
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.inter(color: RentleColors.trustBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
