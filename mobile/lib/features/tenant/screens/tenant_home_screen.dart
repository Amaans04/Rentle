import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/utils/payment_utils.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/repositories/tenant_repository.dart';

final tenantHomeProvider = FutureProvider.autoDispose<TenantHomeData>((ref) {
  return ref.watch(tenantRepositoryProvider).getHome();
});

class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tenantHomeProvider);

    return Scaffold(
      appBar: RentleAppBar(
        showBack: false,
        titleWidget: home.when(
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${d.user.name.isNotEmpty ? d.user.name : 'Tenant'}!',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (d.pg != null)
                Text(
                  d.pg!.name,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Tenant Home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tenantHomeProvider);
          await ref.read(tenantHomeProvider.future);
        },
        child: home.when(
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
                  onPressed: () => ref.invalidate(tenantHomeProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (data) {
          final rent = data.currentRent;
          final isPaid = rent?.status == 'paid';
          final dueSoon = !isPaid &&
              rent?.dueDate != null &&
              rent!.dueDate!.difference(DateTime.now()).inDays <= 3;

          Color cardColor;
          String rentTitle;
          if (isPaid) {
            cardColor = RentleColors.teal;
            rentTitle = 'Rent Paid ✓';
          } else if (dueSoon) {
            cardColor = RentleColors.amber;
            rentTitle = 'Due Soon';
          } else {
            cardColor = RentleColors.coral;
            rentTitle = 'Rent Due';
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              PressableCard(
                color: cardColor.withValues(alpha: 0.12),
                border: Border.all(color: cardColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rentTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
                    if (rent != null) ...[
                      Text(
                        '₹${rent.amount.toInt()}',
                        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${DateFormat.MMMM().format(DateTime(rent.year, rent.month))} ${rent.year}',
                        style: GoogleFonts.inter(),
                      ),
                      if (rent.dueDate != null)
                        Text(
                          'Due: ${DateFormat.yMMMd().format(rent.dueDate!)}',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                    ],
                    if (!isPaid && rent != null) ...[
                      const SizedBox(height: 16),
                      RentleButton(
                        label: 'Pay Now',
                        onPressed: () => _handlePayNow(context, ref, data),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (data.room != null)
                PressableCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Room', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text('Room ${data.room!.roomNumber}', style: GoogleFonts.inter()),
                      if (data.room!.floor != null)
                        Text('Floor ${data.room!.floor}', style: GoogleFonts.inter()),
                      Text(data.room!.roomType, style: GoogleFonts.inter()),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (data.pg != null)
                PressableCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PG Info', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text(data.pg!.address, style: GoogleFonts.inter()),
                      Text('Contact: ${data.pg!.contactPhone}', style: GoogleFonts.inter()),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text('Announcements', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (data.notices.isEmpty)
                Text('No announcements', style: GoogleFonts.inter())
              else
                ...data.notices.map(
                  (n) => PressableCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        Text(n.body, style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _quickAction(context, Icons.report_problem_rounded, 'Complaint', () {
                    _showComplaintSheet(context, ref);
                  }),
                  _quickAction(context, Icons.cleaning_services_rounded, 'Cleaning', () {
                    _showComplaintSheet(context, ref, type: 'cleaning');
                  }),
                  _quickAction(context, Icons.receipt_rounded, 'Receipts', () {
                    context.go('/tenant/payments');
                  }),
                ],
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _quickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: RentleColors.trustBlue),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _handlePayNow(
    BuildContext context,
    WidgetRef ref,
    TenantHomeData data,
  ) async {
    final rent = data.currentRent;
    final upiId = data.pg?.upiId;
    if (rent == null || upiId == null || upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI payment not configured')),
      );
      return;
    }

    final link = PaymentUtils.generateUpiLink(
      upiId: upiId,
      name: data.pg!.name,
      amount: rent.amount.toStringAsFixed(2),
      note: 'Rent for ${DateFormat.MMMM().format(DateTime(rent.year, rent.month))} ${rent.year}',
      transactionRef: rent.recordId,
    );
    await PaymentUtils.launchPayment(link);

    if (!context.mounted) return;
    final paid = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment'),
        content: const Text('Did your payment go through?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );

    if (paid == true) {
      try {
        await ref.read(tenantRepositoryProvider).markPaid(
              recordId: rent.recordId,
              method: 'upi',
            );
        ref.invalidate(tenantHomeProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: RentleColors.teal,
              content: Text('Payment marked as paid'),
            ),
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

  void _showComplaintSheet(
    BuildContext context,
    WidgetRef ref, {
    String type = 'maintenance',
  }) {
    final controller = TextEditingController();
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
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              RentleButton(
                label: 'Submit',
                onPressed: () async {
                  final description = controller.text.trim();
                  if (description.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a description')),
                    );
                    return;
                  }
                  try {
                    await ref.read(tenantRepositoryProvider).submitComplaint(
                          type: type,
                          description: description,
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          backgroundColor: RentleColors.teal,
                          content: Text('Complaint submitted'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(friendlyApiError(e))),
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
