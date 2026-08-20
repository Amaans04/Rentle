import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';

class BuildingFormSheet extends ConsumerStatefulWidget {
  const BuildingFormSheet({super.key, required this.orgId, this.propertyId, this.existing, required this.saving})
    : assert(propertyId != null || existing != null, 'Need propertyId to create, or existing to edit.');

  final String orgId;
  /// Required to create a new building.
  final String? propertyId;
  /// Non-null → edit mode (PATCH this building instead of creating one).
  final Building? existing;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(BuildContext context, {required String orgId, String? propertyId, Building? existing}) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: existing != null ? 'Edit building' : 'Add building',
      saving: saving,
      builder: (_) => BuildingFormSheet(orgId: orgId, propertyId: propertyId, existing: existing, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<BuildingFormSheet> createState() => _BuildingFormSheetState();
}

class _BuildingFormSheetState extends ConsumerState<BuildingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    widget.saving.value = true;
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
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Building name (e.g. "Main Block")'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) => _save(),
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
