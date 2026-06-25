import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';
import 'package:rentle/router/auth_navigation.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getStoredToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      context.go('/welcome');
      return;
    }

    try {
      final me = await repo.getMe();
      if (!mounted) return;

      final user = me.user;
      if (user.role == null) {
        context.go('/welcome');
        return;
      }

      if (user.pgId == null && user.role != UserRoleValues.owner) {
        context.go('/waiting?role=${user.role}');
      } else if (user.role == UserRoleValues.owner && user.pgId == null) {
        context.go('/owner/setup');
      } else {
        AuthNavigation.navigateByRole(context, user.role);
      }
    } catch (_) {
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentleColors.warmSand,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_rounded,
              color: RentleColors.coral,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Rentle',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: RentleColors.trustBlue,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: RentleColors.trustBlue),
          ],
        ),
      ),
    );
  }
}
