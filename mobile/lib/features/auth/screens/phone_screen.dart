import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, required this.role});

  final String role;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  String get _title {
    switch (widget.role) {
      case UserRoleValues.owner:
        return 'Owner Login';
      case UserRoleValues.manager:
        return 'Manager Login';
      case UserRoleValues.tenant:
        return 'Tenant Login';
      default:
        return 'Login';
    }
  }

  Future<void> _sendOtp() async {
    final repo = ref.read(authRepositoryProvider);
    final phone = repo.sanitizePhone(_phoneController.text);
    if (!repo.isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await repo.sendOtp(phone: phone, role: widget.role);
      if (!mounted) return;
      context.push('/auth/otp?phone=$phone&role=${widget.role}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyApiError(e)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RentleAppBar(title: _title),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FadeSlideIn(
          child: Column(
            children: [
              const Icon(Icons.lock_rounded, color: RentleColors.coral, size: 52),
              const SizedBox(height: 24),
              Text(
                'Enter your number',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: RentleColors.charcoal,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: RentleColors.skyBlue.withValues(alpha: 0.25),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      '+91',
                      style: GoogleFonts.inter(fontSize: 16),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '9876543210',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RentleButton(
                label: 'Send OTP',
                loading: _loading,
                onPressed: _sendOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
