import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/utils/tenant_payment_flow.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/rent_record_model.dart';
import 'package:rentle/repositories/tenant_repository.dart';

final tenantPaymentsProvider =
    FutureProvider.autoDispose<List<RentRecordModel>>((ref) {
  return ref.watch(tenantRepositoryProvider).getPayments();
});

class TenantPaymentsScreen extends ConsumerWidget {
  const TenantPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(tenantPaymentsProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Payments', showBack: false),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tenantPaymentsProvider);
          await ref.read(tenantPaymentsProvider.future);
        },
        child: payments.when(
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
                  onPressed: () => ref.invalidate(tenantPaymentsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (list) {
            final unpaid = list.where((r) => r.status != 'paid').toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (unpaid.isNotEmpty) ...[
                  Text(
                    'Pay Now',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...unpaid.map(
                    (record) => PressableCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.displayTitle,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (record.dueDate != null)
                                      Text(
                                        'Due ${DateFormat.yMMMd().format(record.dueDate!)}',
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${record.amount.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: RentleColors.coral,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RentleButton(
                            label: 'Pay via UPI',
                            color: RentleColors.trustBlue,
                            onPressed: () => handleTenantUpiPayment(
                              context,
                              ref,
                              record,
                              onSuccess: () =>
                                  ref.invalidate(tenantPaymentsProvider),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'History',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No payment history yet',
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  )
                else
                  ...list.map((record) {
                    final isPaid = record.status == 'paid';
                    return PressableCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.displayTitle,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (record.paidAt != null)
                                  Text(
                                    'Paid ${DateFormat.yMMMd().format(record.paidAt!)}',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${record.amount.toInt()}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isPaid ? Icons.check_circle : Icons.schedule,
                            color: isPaid ? RentleColors.teal : RentleColors.coral,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
