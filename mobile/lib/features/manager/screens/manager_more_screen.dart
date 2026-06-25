import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';

class ManagerMoreScreen extends ConsumerWidget {
  const ManagerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const RentleAppBar(title: 'More', showBack: false),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(me?.user.name ?? 'Manager'),
            subtitle: Text(me?.pg?.name ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            onTap: () => context.push('/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: RentleColors.coral),
            title: Text('Logout', style: GoogleFonts.inter(color: RentleColors.coral)),
            onTap: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}
