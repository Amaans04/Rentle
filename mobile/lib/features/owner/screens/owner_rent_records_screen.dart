import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/rent_record_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerRentRecordsProvider =
    FutureProvider.autoDispose<List<RentRecordModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getRentRecords();
});

class OwnerRentRecordsScreen extends ConsumerWidget {
  const OwnerRentRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(ownerRentRecordsProvider);

    return Scaffold(
      appBar: RentleAppBar(
        title: 'Rent Records',
        fallbackRoute: '/owner/more',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                await ref.read(ownerRepositoryProvider).generateRentRecords();
                ref.invalidate(ownerRentRecordsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('No rent records', style: GoogleFonts.inter()),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final record = list[index];
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
                            record.tenantName ?? 'Tenant',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${DateFormat.MMMM().format(DateTime(record.year, record.month))} ${record.year}',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          Text(
                            'Room ${record.roomNumber ?? '-'}',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${record.amount.toInt()}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isPaid ? RentleColors.teal : RentleColors.coral)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.status,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isPaid ? RentleColors.teal : RentleColors.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
