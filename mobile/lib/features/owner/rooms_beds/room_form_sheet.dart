import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

const _roomTypes = ['single', 'double', 'triple', 'dormitory'];

class RoomFormSheet extends ConsumerStatefulWidget {
  const RoomFormSheet({
    super.key,
    required this.orgId,
    this.propertyId,
    this.floorId,
    this.existing,
    required this.saving,
  }) : assert(
         (propertyId != null && floorId != null) || existing != null,
         'Need propertyId+floorId to create, or existing to edit.',
       );

  final String orgId;
  /// Required (with floorId) to create a new room.
  final String? propertyId;
  final String? floorId;
  /// Non-null → edit mode (PATCH this room instead of creating one). floorId
  /// can't be changed via PATCH (server's updateRoomSchema omits it).
  final Room? existing;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(
    BuildContext context, {
    required String orgId,
    String? propertyId,
    String? floorId,
    Room? existing,
  }) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: existing != null ? 'Edit room' : 'Add room',
      saving: saving,
      builder: (_) =>
          RoomFormSheet(orgId: orgId, propertyId: propertyId, floorId: floorId, existing: existing, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends ConsumerState<RoomFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _roomNumber = TextEditingController(text: widget.existing?.roomNumber);
  late final _sharingCapacity = TextEditingController(text: (widget.existing?.sharingCapacity ?? 1).toString());
  late final _rentAmount = TextEditingController(text: widget.existing?.rentAmount.toStringAsFixed(0));
  late final _mrpAmount = TextEditingController(text: widget.existing?.mrpAmount.toStringAsFixed(0));
  late String _roomType = widget.existing?.roomType ?? 'single';

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _roomNumber.dispose();
    _sharingCapacity.dispose();
    _rentAmount.dispose();
    _mrpAmount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      final data = {
        'roomNumber': _roomNumber.text.trim(),
        'roomType': _roomType,
        'sharingCapacity': int.parse(_sharingCapacity.text.trim()),
        'rentAmount': double.parse(_rentAmount.text.trim()),
        'mrpAmount': double.parse(_mrpAmount.text.trim()),
      };
      if (_isEdit) {
        await api.dio.patch('/organizations/${widget.orgId}/rooms/${widget.existing!.id}', data: data);
      } else {
        await api.dio.post(
          '/organizations/${widget.orgId}/properties/${widget.propertyId}/rooms',
          data: {...data, 'floorId': widget.floorId},
        );
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
            controller: _roomNumber,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Room number'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _roomType,
            decoration: const InputDecoration(labelText: 'Room type'),
            items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _roomType = v ?? 'single'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sharingCapacity,
            decoration: const InputDecoration(labelText: 'Sharing capacity (number of beds)'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 1) ? 'Must be at least 1' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rentAmount,
            decoration: const InputDecoration(labelText: 'Rent amount (₹/month)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mrpAmount,
            decoration: const InputDecoration(labelText: 'MRP amount (₹/month)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
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
