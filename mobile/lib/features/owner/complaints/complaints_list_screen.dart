import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/complaint_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/status_badge.dart';
import '../owner_providers.dart';
import 'complaint_detail_screen.dart';

const _statusFilters = [null, 'OPEN', 'IN_PROGRESS', 'ESCALATED', 'RESOLVED', 'CLOSED'];

Color complaintStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.semanticColors;
  switch (status) {
    case 'OPEN':
      return semantic.warning;
    case 'IN_PROGRESS':
      return scheme.primary;
    case 'ESCALATED':
      return scheme.error;
    case 'RESOLVED':
      return semantic.success;
    case 'CLOSED':
      return scheme.onSurfaceVariant;
    default:
      return scheme.outline;
  }
}

Color priorityColor(BuildContext context, String priority) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.semanticColors;
  switch (priority) {
    case 'URGENT':
      return scheme.error;
    case 'HIGH':
      return semantic.warning;
    case 'MEDIUM':
      return scheme.primary;
    default:
      return scheme.outline;
  }
}

class ComplaintsListScreen extends ConsumerStatefulWidget {
  const ComplaintsListScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  ConsumerState<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends ConsumerState<ComplaintsListScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id, status: _status, priority: null);
    final complaints = ref.watch(complaintsProvider(key));

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
          child: AsyncValueView<List<Complaint>>(
            value: complaints,
            onRetry: () => ref.invalidate(complaintsProvider(key)),
            data: (context, list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.report_problem_outlined,
                  title: 'No complaints here',
                  subtitle: 'Tenants file these from their own app.',
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(complaintsProvider(key).future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final c = list[index];
                    return StaggeredEntrance(
                      index: index,
                      child: AppListCard(
                        leadingIcon: Icons.report_problem,
                        leadingColor: complaintStatusColor(context, c.status),
                        title: c.title,
                        subtitle: '${c.reporterName ?? 'Tenant'} · ${titleCase(c.status)}',
                        trailing: StatusBadge(label: c.priority, color: priorityColor(context, c.priority)),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ComplaintDetailScreen(orgId: widget.orgId, complaintId: c.id)),
                          );
                          ref.invalidate(complaintsProvider(key));
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
