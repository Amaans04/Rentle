import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/invoice_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/status_badge.dart';
import '../owner_providers.dart';
import 'invoice_detail_screen.dart';

const _statusFilters = [null, 'SENT', 'OVERDUE', 'PARTIALLY_PAID', 'PAID'];

Color invoiceStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.semanticColors;
  switch (status) {
    case 'PAID':
      return semantic.success;
    case 'PARTIALLY_PAID':
      return semantic.warning;
    case 'OVERDUE':
      return scheme.error;
    case 'VOID':
    case 'REFUNDED':
      return scheme.onSurfaceVariant;
    default:
      return scheme.outline;
  }
}

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id, status: _status);
    final invoices = ref.watch(invoicesProvider(key));

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
          child: AsyncValueView<List<Invoice>>(
            value: invoices,
            onRetry: () => ref.invalidate(invoicesProvider(key)),
            data: (context, list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long,
                  title: 'No invoices yet',
                  subtitle: 'Use "Generate invoices" to create this month\'s.',
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(invoicesProvider(key).future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final invoice = list[index];
                    return StaggeredEntrance(
                      index: index,
                      child: AppListCard(
                        leadingIcon: Icons.receipt,
                        leadingColor: invoiceStatusColor(context, invoice.status),
                        title: invoice.invoiceNumber,
                        subtitle: 'Due ${formatDate(invoice.dueDate)}',
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMoney(invoice.balance > 0 ? invoice.balance : invoice.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            StatusBadge(label: titleCase(invoice.status), color: invoiceStatusColor(context, invoice.status)),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => InvoiceDetailScreen(orgId: widget.orgId, invoice: invoice)),
                          );
                          ref.invalidate(invoicesProvider(key));
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
