import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/complaint_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerComplaintsProvider =
    FutureProvider.autoDispose<List<ComplaintModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getComplaints();
});

class OwnerComplaintsScreen extends ConsumerWidget {
  const OwnerComplaintsScreen({super.key, this.showBack = true});

  final bool showBack;

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return RentleColors.teal;
      case 'in_progress':
        return RentleColors.amber;
      default:
        return RentleColors.coral;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = ref.watch(ownerComplaintsProvider);

    return Scaffold(
      appBar: RentleAppBar(
        title: 'Complaints',
        showBack: showBack,
        fallbackRoute: showBack ? '/owner/more' : null,
      ),
      body: complaints.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('No complaints', style: GoogleFonts.inter()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final c = list[index];
              return PressableCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.type,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(c.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.status,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _statusColor(c.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(c.description, style: GoogleFonts.inter(fontSize: 14)),
                    if (c.tenantName != null)
                      Text(
                        '${c.tenantName} • Room ${c.roomNumber ?? '-'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: RentleColors.charcoal.withValues(alpha: 0.6),
                        ),
                      ),
                    if (c.status != 'resolved') ...[
                      const SizedBox(height: 12),
                      RentleButton(
                        label: 'Mark In Progress',
                        color: RentleColors.amber,
                        onPressed: () async {
                          await ref
                              .read(ownerRepositoryProvider)
                              .updateComplaint(c.complaintId, status: 'in_progress');
                          ref.invalidate(ownerComplaintsProvider);
                        },
                      ),
                    ],
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
