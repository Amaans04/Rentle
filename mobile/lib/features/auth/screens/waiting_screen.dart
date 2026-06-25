import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';

class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key, required this.role});

  final String role;

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authStateProvider).value?.user.phone ?? '';

    return Scaffold(
      appBar: const RentleAppBar(
        title: 'Waiting for Invite',
        fallbackRoute: '/welcome',
      ),
      backgroundColor: RentleColors.warmSand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: RentleColors.amber,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "You're not added yet",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: RentleColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask your owner to add you using your phone number',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RentleColors.charcoal.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              if (phone.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.phone, size: 18),
                  label: Text('+91 $phone'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone copied')),
                    );
                  },
                ),
              const SizedBox(height: 32),
              Opacity(
                opacity: 0.6,
                child: PressableCard(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: RentleColors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Find nearby PGs — Coming soon',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/welcome');
                },
                child: Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    color: RentleColors.charcoal.withValues(alpha: 0.4),
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
