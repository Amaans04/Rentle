import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/owner/screens/owner_add_charge_screen.dart';
import 'package:rentle/models/tenant_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerTenantsProvider =
    FutureProvider.autoDispose<List<TenantModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getTenants();
});

class OwnerTenantsScreen extends ConsumerStatefulWidget {
  const OwnerTenantsScreen({super.key});

  @override
  ConsumerState<OwnerTenantsScreen> createState() => _OwnerTenantsScreenState();
}

class _OwnerTenantsScreenState extends ConsumerState<OwnerTenantsScreen> {
  String _query = '';

  Color _rentColor(String? status) {
    switch (status) {
      case 'paid':
        return RentleColors.teal;
      case 'due_soon':
        return RentleColors.amber;
      default:
        return RentleColors.coral;
    }
  }

  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Tenant',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              RentleButton(
                label: 'Add by Phone Number',
                color: RentleColors.coral,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/owner/tenants/add');
                },
              ),
              const SizedBox(height: 12),
              RentleButton(
                label: 'Pick from Contacts',
                color: RentleColors.trustBlue,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/owner/tenants/pick-contact');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddCharge(TenantModel tenant) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnerAddChargeScreen(tenant: tenant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(ownerTenantsProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Tenants', showBack: false),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: tenants.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(friendlyApiError(e), textAlign: TextAlign.center),
                ),
              ),
              data: (list) {
                final filtered = list.where((t) {
                  if (_query.isEmpty) return true;
                  return (t.name ?? '').toLowerCase().contains(_query) ||
                      (t.phone ?? '').contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No tenants', style: GoogleFonts.inter()),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ownerTenantsProvider);
                    await ref.read(ownerTenantsProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tenant = filtered[index];
                      final initials = (tenant.name ?? 'T')
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase();
                      return PressableCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        onTap: () => _openAddCharge(tenant),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: RentleColors.trustBlue
                                  .withValues(alpha: 0.15),
                              child: Text(
                                initials,
                                style: GoogleFonts.inter(
                                  color: RentleColors.trustBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenant.name ?? 'Tenant',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Room ${tenant.roomNumber ?? '-'}',
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                  if (tenant.phone != null)
                                    Text(
                                      '+91 ${tenant.phone!}',
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _rentColor(tenant.rentStatus)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tenant.rentStatus ?? 'unpaid',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _rentColor(tenant.rentStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
