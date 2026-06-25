import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/owner/screens/owner_complaints_screen.dart';
import 'package:rentle/repositories/owner_repository.dart';

final managerDashboardProvider =
    FutureProvider.autoDispose<OwnerDashboardData>((ref) {
  return ref.watch(ownerRepositoryProvider).getDashboard();
});

class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(managerDashboardProvider);
    final complaints = ref.watch(ownerComplaintsProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Manager Home', showBack: false),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final openComplaints = complaints.maybeWhen(
            data: (list) =>
                list.where((c) => c.status != 'resolved').length,
            orElse: () => 0,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Tenants',
                      '${data.summary['occupied'] ?? 0}',
                      RentleColors.trustBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Open Complaints',
                      '$openComplaints',
                      RentleColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statCard(
                'Pending Rent',
                '₹${(data.summary['rentCollected'] ?? 0)} collected',
                RentleColors.coral,
              ),
              const SizedBox(height: 24),
              Text('Recent Complaints', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              complaints.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Text(e.toString()),
                data: (list) {
                  final recent = list.take(5).toList();
                  if (recent.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('No complaints', style: GoogleFonts.inter()),
                    );
                  }
                  return Column(
                    children: recent
                        .map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.type),
                            subtitle: Text(c.description),
                            trailing: Text(c.status),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              RentleButton(
                label: 'Send Notice',
                color: RentleColors.teal,
                onPressed: () {},
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return PressableCard(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
        ],
      ),
    );
  }
}

class ManagerComplaintsScreen extends ConsumerWidget {
  const ManagerComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const OwnerComplaintsScreen(showBack: false);
  }
}
