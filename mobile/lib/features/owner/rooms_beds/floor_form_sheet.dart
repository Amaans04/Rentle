import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';

class FloorFormSheet extends ConsumerStatefulWidget {
  const FloorFormSheet({super.key, required this.orgId, this.buildingId, this.existing})
    : assert(buildingId != null || existing != null, 'Need buildingId to create, or existing to edit.');

  final String orgId;
  /// Required to create a new floor.
  final String? buildingId;
  /// Non-null → edit mode (PATCH this floor instead of creating one).
  final Floor? existing;

  @override
  ConsumerState<FloorFormSheet> createState() => _FloorFormSheetState();
}

class _FloorFormSheetState extends ConsumerState<FloorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _level = TextEditingController(text: (widget.existing?.level ?? 0).toString());
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = {'name': _name.text.trim(), 'level': int.parse(_level.text.trim())};
      if (_isEdit) {
        await api.dio.patch('/organizations/${widget.orgId}/floors/${widget.existing!.id}', data: data);
      } else {
        await api.dio.post('/organizations/${widget.orgId}/buildings/${widget.buildingId}/floors', data: data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit floor' : 'Add floor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Floor name (e.g. "Ground", "2")'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _level,
              decoration: const InputDecoration(labelText: 'Sort order (0 = ground)'),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v ?? '') == null ? 'Must be a number' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
