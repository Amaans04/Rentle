import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/idempotency.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

class GenerateInvoicesSheet extends ConsumerStatefulWidget {
  const GenerateInvoicesSheet({super.key, required this.orgId, required this.propertyId, required this.saving});

  final String orgId;
  final String propertyId;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(BuildContext context, {required String orgId, required String propertyId}) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: 'Generate invoices',
      saving: saving,
      builder: (_) => GenerateInvoicesSheet(orgId: orgId, propertyId: propertyId, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<GenerateInvoicesSheet> createState() => _GenerateInvoicesSheetState();
}

class _GenerateInvoicesSheetState extends ConsumerState<GenerateInvoicesSheet> {
  late DateTime _period = DateTime.now();

  Future<void> _generate() async {
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post(
        '/organizations/${widget.orgId}/properties/${widget.propertyId}/invoices/generate',
        data: {'year': _period.year, 'month': _period.month},
        options: Options(headers: {'Idempotency-Key': newIdempotencyKey()}),
      );
      final generated = (res.data['data'] as Map)['generated'] as int;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Generated $generated invoice(s) for ${_period.month}/${_period.year}.')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      widget.saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Creates one invoice per active tenancy for the selected month. Safe to re-run — already-invoiced tenancies are skipped.'),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${_period.month}/${_period.year}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _period,
              firstDate: DateTime(2024),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
            );
            if (picked != null) setState(() => _period = picked);
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: widget.saving,
          builder: (context, saving, _) => FilledButton(
            onPressed: saving ? null : _generate,
            child: saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate'),
          ),
        ),
      ],
    );
  }
}
