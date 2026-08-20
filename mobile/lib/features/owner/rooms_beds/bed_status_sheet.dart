import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

// OCCUPIED deliberately excluded — server rejects manual transitions into or
// out of it; occupancy is a side-effect of the tenancy lifecycle instead.
const _manualStatuses = ['VACANT', 'RESERVED', 'BLOCKED', 'MAINTENANCE', 'CLEANING'];

class BedStatusSheet extends ConsumerStatefulWidget {
  const BedStatusSheet({super.key, required this.orgId, required this.bed, required this.saving});

  final String orgId;
  final Bed bed;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(BuildContext context, {required String orgId, required Bed bed}) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: 'Bed ${bed.bedLabel} status',
      saving: saving,
      builder: (_) => BedStatusSheet(orgId: orgId, bed: bed, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<BedStatusSheet> createState() => _BedStatusSheetState();
}

class _BedStatusSheetState extends ConsumerState<BedStatusSheet> {
  late String _status = _manualStatuses.contains(widget.bed.status) ? widget.bed.status : 'VACANT';
  final _blockedReason = TextEditingController();
  DateTime? _reservedUntil;

  @override
  void dispose() {
    _blockedReason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_status == 'RESERVED' && _reservedUntil == null) {
      showErrorSnackBar(context, 'Pick a reserved-until date.');
      return;
    }
    if (_status == 'BLOCKED' && _blockedReason.text.trim().isEmpty) {
      showErrorSnackBar(context, 'A reason is required to block a bed.');
      return;
    }
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch(
        '/organizations/${widget.orgId}/beds/${widget.bed.id}/status',
        data: {
          'status': _status,
          if (_status == 'RESERVED') 'reservedUntil': _reservedUntil!.toIso8601String(),
          if (_status == 'BLOCKED') 'blockedReason': _blockedReason.text.trim(),
        },
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
    if (widget.bed.status == 'OCCUPIED') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          const Text(
            'Its status changes automatically with the tenancy — use notice / move-out / transfer on the tenant instead.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _manualStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        if (_status == 'RESERVED') ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_reservedUntil == null ? 'Pick reserved-until date' : 'Until ${_reservedUntil!.toLocal()}'.split(' ')[0]),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _reservedUntil = picked);
            },
          ),
        ],
        if (_status == 'BLOCKED') ...[
          const SizedBox(height: 12),
          TextFormField(controller: _blockedReason, decoration: const InputDecoration(labelText: 'Reason')),
        ],
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: widget.saving,
          builder: (context, saving, _) => FilledButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ),
      ],
    );
  }
}
