import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/idempotency.dart';
import '../../../core/models/invoice_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

const _methods = ['CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'WALLET'];

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.orgId, required this.invoice, required this.saving});

  final String orgId;
  final Invoice invoice;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(BuildContext context, {required String orgId, required Invoice invoice}) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: 'Record payment',
      saving: saving,
      builder: (_) => RecordPaymentSheet(orgId: orgId, invoice: invoice, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.invoice.balance.toStringAsFixed(0));
  final _utr = TextEditingController();
  String _method = 'CASH';

  @override
  void dispose() {
    _amount.dispose();
    _utr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/organizations/${widget.orgId}/payments',
        data: {
          'invoiceId': widget.invoice.id,
          'amount': double.parse(_amount.text.trim()),
          'method': _method,
          if (_utr.text.trim().isNotEmpty) 'utr': _utr.text.trim(),
        },
        options: Options(headers: {'Idempotency-Key': newIdempotencyKey()}),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      widget.saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Amount (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Must be greater than 0';
              if (n > widget.invoice.balance) return 'Exceeds remaining balance (₹${widget.invoice.balance.toStringAsFixed(0)})';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _utr, decoration: const InputDecoration(labelText: 'UTR / reference (optional)')),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: widget.saving,
            builder: (context, saving, _) => FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Record payment'),
            ),
          ),
        ],
      ),
    );
  }
}
