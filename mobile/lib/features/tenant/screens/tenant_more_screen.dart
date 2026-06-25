import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/repositories/tenant_repository.dart';

class TenantMoreScreen extends ConsumerWidget {
  const TenantMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const RentleAppBar(title: 'More', showBack: false),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(me?.user.name ?? 'Tenant'),
            subtitle: Text(me?.user.phone ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Documents'),
            subtitle: const Text('Aadhaar, PAN, Photo — coming soon'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: RentleColors.amber),
            title: const Text('Give Notice'),
            onTap: () => _giveNotice(context, ref),
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

  Future<void> _giveNotice(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    try {
      await ref.read(tenantRepositoryProvider).giveNotice(moveOutDate: date);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice submitted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    }
  }
}
