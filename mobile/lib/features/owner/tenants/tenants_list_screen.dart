import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/models/tenancy_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/status_badge.dart';
import '../owner_providers.dart';
import 'tenant_detail_screen.dart';

const _statusFilters = [null, 'PENDING_ONBOARDING', 'ACTIVE', 'NOTICE_GIVEN', 'ARCHIVED'];

Color tenancyStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.semanticColors;
  switch (status) {
    case 'ACTIVE':
      return semantic.success;
    case 'PENDING_ONBOARDING':
      return semantic.warning;
    case 'NOTICE_GIVEN':
      return scheme.error;
    case 'ARCHIVED':
      return scheme.onSurfaceVariant;
    default:
      return scheme.outline;
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
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No tenants here yet',
                  subtitle: 'Use "Invite tenant" to add one.',
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(tenanciesProvider(key).future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final tenancy = list[index];
                    return StaggeredEntrance(
                      index: index,
                      child: AppListCard(
                        leadingIcon: Icons.person,
                        leadingColor: tenancyStatusColor(context, tenancy.status),
                        title: tenancy.displayName,
                        subtitle: 'Bed ${tenancy.bedLabel ?? '—'} · ${formatMoney(tenancy.rentAmount)}/mo',
                        trailing: StatusBadge(label: titleCase(tenancy.status), color: tenancyStatusColor(context, tenancy.status)),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TenantDetailScreen(orgId: widget.orgId, propertyId: widget.property.id, tenancy: tenancy),
                            ),
                          );
                          ref.invalidate(tenanciesProvider(key));
                        },
                      ),
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
