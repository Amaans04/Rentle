import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/invoice_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';
import 'invoices_list_screen.dart' show invoiceStatusColor;
import 'record_payment_sheet.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.orgId, required this.invoice});

  final String orgId;
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (orgId: orgId, invoiceId: invoice.id);
    final detail = ref.watch(invoiceDetailProvider(key));
    final currentBalance = detail.valueOrNull?.invoice.balance ?? invoice.balance;

    return Scaffold(
      appBar: AppBar(title: Text(invoice.invoiceNumber)),
      body: AsyncValueView<InvoiceDetail>(
        value: detail,
        onRetry: () => ref.invalidate(invoiceDetailProvider(key)),
        data: (context, d) {
          final inv = d.invoice;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(titleCase(inv.status)),
                            backgroundColor: invoiceStatusColor(context, inv.status).withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: invoiceStatusColor(context, inv.status)),
                          ),
                          const Spacer(),
                          Text(formatMoney(inv.totalAmount), style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Period: ${formatDate(inv.periodStart)} – ${formatDate(inv.periodEnd)}'),
                      Text('Due: ${formatDate(inv.dueDate)}'),
                      Text('Paid so far: ${formatMoney(inv.paidAmount)}'),
                      if (inv.balance > 0) Text('Balance: ${formatMoney(inv.balance)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Line items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...inv.lineItems.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.description),
                  subtitle: Text(titleCase(item.category)),
                  trailing: Text(formatMoney(item.amount)),
                ),
              ),
              if (d.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Payments', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...d.payments.map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline, color: context.semanticColors.success),
                    title: Text(formatMoney(p.amount)),
                    subtitle: Text('${titleCase(p.method)}${p.utr != null ? ' · ${p.utr}' : ''}'),
                    trailing: Text(formatDate(p.paidAt)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: currentBalance > 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final recorded = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => RecordPaymentSheet(orgId: orgId, invoice: detail.valueOrNull?.invoice ?? invoice),
                );
                if (recorded == true) ref.invalidate(invoiceDetailProvider(key));
              },
              icon: const Icon(Icons.payments),
              label: const Text('Record payment'),
            )
          : null,
    );
  }
}
