import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerDashboardProvider =
    FutureProvider.autoDispose<OwnerDashboardData>((ref) {
  return ref.watch(ownerRepositoryProvider).getDashboard();
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final me = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: RentleAppBar(
        showBack: false,
        titleWidget: Row(
          children: [
            Text('Rentle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              me?.pg?.name ?? '',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.notifications_none_rounded),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerDashboardProvider);
          await ref.read(ownerDashboardProvider.future);
        },
        child: dashboard.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              Icon(Icons.error_outline, size: 48, color: RentleColors.coral),
              const SizedBox(height: 16),
              Text(
                friendlyApiError(e),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(ownerDashboardProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (data) {
          final summary = data.summary;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _summaryCard('Total Rooms', summary['totalRooms'] ?? 0,
                        RentleColors.trustBlue),
                    _summaryCard('Occupied', summary['occupied'] ?? 0,
                        RentleColors.teal),
                    _summaryCard('Vacant', summary['vacant'] ?? 0,
                        RentleColors.coral),
                    _summaryCard(
                      'Rent Collected',
                      summary['rentCollected'] ?? 0,
                      RentleColors.amber,
                      prefix: '₹',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Quick Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _action(Icons.person_add_rounded, 'Add Tenant',
                      RentleColors.trustBlue, () => context.push('/owner/tenants/add')),
                  _action(Icons.payments_rounded, 'Collect Rent',
                      RentleColors.coral, () => context.push('/owner/rent-records')),
                  _action(Icons.report_problem_rounded, 'Complaints',
                      RentleColors.amber, () => context.push('/owner/complaints')),
                  _action(Icons.campaign_rounded, 'Notice Board',
                      RentleColors.teal, () => context.push('/owner/notices')),
                ],
              ),
              const SizedBox(height: 24),
              Text('Recent Activity', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (data.activities.isEmpty)
                Text('No recent activity', style: GoogleFonts.inter())
              else
                ...data.activities.map((a) {
                  final type = a['type'] as String? ?? '';
                  final title = type == 'payment'
                      ? 'Payment received'
                      : 'New complaint';
                  final subtitle = type == 'payment'
                      ? '₹${a['amount'] ?? 0}'
                      : a['description']?.toString() ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: type == 'payment'
                          ? RentleColors.teal.withValues(alpha: 0.2)
                          : RentleColors.amber.withValues(alpha: 0.2),
                      child: Icon(
                        type == 'payment'
                            ? Icons.payments_rounded
                            : Icons.report_problem_rounded,
                        color: type == 'payment'
                            ? RentleColors.teal
                            : RentleColors.amber,
                      ),
                    ),
                    title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
                  );
                }),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int value, Color color, {String prefix = ''}) {
    return PressableCard(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$prefix${NumberFormat.compact().format(value)}',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: RentleColors.charcoal)),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return PressableCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
