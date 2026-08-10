import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/models/tenancy_models.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';
import 'tenant_detail_screen.dart';

const _statusFilters = [null, 'PENDING_ONBOARDING', 'ACTIVE', 'NOTICE_GIVEN', 'ARCHIVED'];

Color tenancyStatusColor(String status) {
  switch (status) {
    case 'ACTIVE':
      return Colors.green;
    case 'PENDING_ONBOARDING':
      return Colors.orange;
    case 'NOTICE_GIVEN':
      return Colors.deepOrange;
    case 'ARCHIVED':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

class TenantsListScreen extends ConsumerStatefulWidget {
  const TenantsListScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  ConsumerState<TenantsListScreen> createState() => _TenantsListScreenState();
}

class _TenantsListScreenState extends ConsumerState<TenantsListScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id, status: _status);
    final tenancies = ref.watch(tenanciesProvider(key));

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: _statusFilters
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s == null ? 'All' : titleCase(s)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Tenancy>>(
            value: tenancies,
            onRetry: () => ref.invalidate(tenanciesProvider(key)),
            data: (context, list) {
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No tenants here yet. Use "Invite tenant" to add one.', textAlign: TextAlign.center),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(tenanciesProvider(key).future),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tenancy = list[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: tenancyStatusColor(tenancy.status),
                        child: Text(
                          tenancy.displayName.isNotEmpty ? tenancy.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(tenancy.displayName),
                      subtitle: Text('Bed ${tenancy.bedLabel ?? '—'} · ${titleCase(tenancy.status)} · ${formatMoney(tenancy.rentAmount)}/mo'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TenantDetailScreen(orgId: widget.orgId, propertyId: widget.property.id, tenancy: tenancy),
                          ),
                        );
                        ref.invalidate(tenanciesProvider(key));
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
