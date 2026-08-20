import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

class BedFormSheet extends ConsumerStatefulWidget {
  const BedFormSheet({
    super.key,
    required this.orgId,
    this.roomId,
    this.suggestedLabel,
    this.existing,
    required this.saving,
  }) : assert(roomId != null || existing != null, 'Need roomId to create, or existing to edit.');

  final String orgId;
  /// Required to create a new bed.
  final String? roomId;
  final String? suggestedLabel;
  /// Non-null → edit mode (PATCH this bed instead of creating one).
  final Bed? existing;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(
    BuildContext context, {
    required String orgId,
    String? roomId,
    String? suggestedLabel,
    Bed? existing,
  }) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: existing != null ? 'Edit bed' : 'Add bed',
      saving: saving,
      builder: (_) =>
          BedFormSheet(orgId: orgId, roomId: roomId, suggestedLabel: suggestedLabel, existing: existing, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<BedFormSheet> createState() => _BedFormSheetState();
}

class _BedFormSheetState extends ConsumerState<BedFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _bedLabel = TextEditingController(text: widget.existing?.bedLabel ?? widget.suggestedLabel ?? '');
  late final _rentAmount = TextEditingController(text: widget.existing?.rentAmount?.toStringAsFixed(0));

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _bedLabel.dispose();
    _rentAmount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      final data = {
        'bedLabel': _bedLabel.text.trim(),
        if (_rentAmount.text.trim().isNotEmpty) 'rentAmount': double.parse(_rentAmount.text.trim()),
      };
      if (_isEdit) {
        await api.dio.patch('/organizations/${widget.orgId}/beds/${widget.existing!.id}', data: data);
      } else {
        await api.dio.post('/organizations/${widget.orgId}/rooms/${widget.roomId}/beds', data: data);
      }
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
            controller: _bedLabel,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Bed label (e.g. "A", "1")'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rentAmount,
            decoration: const InputDecoration(labelText: 'Rent override (optional — defaults to room rent)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: widget.saving,
            builder: (context, saving, _) => FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Save' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }
}
