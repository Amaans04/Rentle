import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';

class BuildingFormSheet extends ConsumerStatefulWidget {
  const BuildingFormSheet({super.key, required this.orgId, this.propertyId, this.existing})
    : assert(propertyId != null || existing != null, 'Need propertyId to create, or existing to edit.');

  final String orgId;
  /// Required to create a new building.
  final String? propertyId;
  /// Non-null → edit mode (PATCH this building instead of creating one).
  final Building? existing;

  @override
  ConsumerState<BuildingFormSheet> createState() => _BuildingFormSheetState();
}

class _BuildingFormSheetState extends ConsumerState<BuildingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_isEdit) {
        await api.dio.patch(
          '/organizations/${widget.orgId}/buildings/${widget.existing!.id}',
          data: {'name': _name.text.trim()},
        );
      } else {
        await api.dio.post(
          '/organizations/${widget.orgId}/properties/${widget.propertyId}/buildings',
          data: {'name': _name.text.trim()},
        );
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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit building' : 'Add building', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Building name (e.g. "Main Block")'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) => _save(),
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
