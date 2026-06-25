import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/models/tenant_model.dart';
import 'package:rentle/repositories/auth_repository.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerStaffProvider = FutureProvider.autoDispose<List<StaffModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getStaff();
});

class OwnerStaffScreen extends ConsumerWidget {
  const OwnerStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(ownerStaffProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Staff & Managers'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddManager(context, ref),
        child: const Icon(Icons.add),
      ),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('No staff yet', style: GoogleFonts.inter()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final member = list[index];
              return PressableCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: RentleColors.trustBlue.withValues(alpha: 0.15),
                    child: Text(member.name.isNotEmpty ? member.name[0] : 'M'),
                  ),
                  title: Text(member.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(member.phone),
                  trailing: Icon(
                    member.active ? Icons.check_circle : Icons.cancel,
                    color: member.active ? RentleColors.teal : RentleColors.coral,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddManager(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Manager', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  counterText: '',
                ),
              ),
              RentleButton(
                label: 'Send Invite',
                onPressed: () async {
                  final phone =
                      ref.read(authRepositoryProvider).sanitizePhone(
                            phoneController.text,
                          );
                  try {
                    await ref
                        .read(ownerRepositoryProvider)
                        .inviteStaff(phone: phone);
                    ref.invalidate(ownerStaffProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class OwnerMoreScreen extends ConsumerWidget {
  const OwnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const RentleAppBar(title: 'More', showBack: false),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(me?.user.name ?? 'Owner', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text('${me?.user.phone ?? ''}\n${me?.pg?.name ?? ''}'),
            isThreeLine: true,
          ),
          const Divider(),
          _item(context, Icons.manage_accounts_rounded, 'Staff & Managers', '/owner/staff'),
          _item(context, Icons.report_problem_rounded, 'Complaints', '/owner/complaints'),
          _item(context, Icons.campaign_rounded, 'Notice Board', '/owner/notices'),
          _item(context, Icons.receipt_long_rounded, 'Rent Records', '/owner/rent-records'),
          _item(context, Icons.settings_rounded, 'Settings', '/settings'),
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

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: RentleColors.trustBlue),
      title: Text(title, style: GoogleFonts.inter()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
