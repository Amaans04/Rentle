import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _upiController;

  @override
  void initState() {
    super.initState();
    final upi = ref.read(authStateProvider).value?.pg?.upiId ?? '';
    _upiController = TextEditingController(text: upi);
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: const RentleAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('PG Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(me?.pg?.name ?? '', style: GoogleFonts.inter()),
          Text(me?.pg?.address ?? '', style: GoogleFonts.inter()),
          const SizedBox(height: 24),
          TextField(
            controller: _upiController,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'owner@upi',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for tenant rent payments via UPI deep links',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          const SizedBox(height: 24),
          Text(
            'Rent due date: ${me?.pg?.rentDueDate ?? 1}',
            style: GoogleFonts.inter(),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
