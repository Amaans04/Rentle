import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';

const _propertyTypes = ['PG', 'HOSTEL', 'CO_LIVING', 'APARTMENT'];

class PropertyFormScreen extends ConsumerStatefulWidget {
  const PropertyFormScreen({super.key, required this.orgId, this.existing});

  final String orgId;

  /// Non-null → edit mode (PATCH the existing property instead of creating one).
  final Property? existing;

  @override
  ConsumerState<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends ConsumerState<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _slug = TextEditingController(text: widget.existing?.slug);
  late final _line1 = TextEditingController(
    text: widget.existing?.address.line1,
  );
  late final _line2 = TextEditingController(
    text: widget.existing?.address.line2,
  );
  late final _city = TextEditingController(text: widget.existing?.address.city);
  late final _state = TextEditingController(
    text: widget.existing?.address.state,
  );
  late final _pincode = TextEditingController(
    text: widget.existing?.address.pincode,
  );
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _rentDueDay = TextEditingController(
    text: (widget.existing?.rentDueDay ?? 5).toString(),
  );
  late final _gracePeriodDays = TextEditingController(
    text: (widget.existing?.gracePeriodDays ?? 3).toString(),
  );
  late String _type = widget.existing?.type ?? 'PG';
  bool _slugEdited = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _slug,
      _line1,
      _line2,
      _city,
      _state,
      _pincode,
      _phone,
      _rentDueDay,
      _gracePeriodDays,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (_slugEdited || _isEdit) return;
    final slug = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slug.text = slug;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = {
        'name': _name.text.trim(),
        'slug': _slug.text.trim(),
        'type': _type,
        'address': {
          'line1': _line1.text.trim(),
          if (_line2.text.trim().isNotEmpty) 'line2': _line2.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'pincode': _pincode.text.trim(),
        },
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        'rentDueDay': int.parse(_rentDueDay.text.trim()),
        'gracePeriodDays': int.parse(_gracePeriodDays.text.trim()),
      };
      if (_isEdit) {
        await api.dio.patch(
          '/organizations/${widget.orgId}/properties/${widget.existing!.id}',
          data: data,
        );
      } else {
        await api.dio.post(
          '/organizations/${widget.orgId}/properties',
          data: data,
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
    // A cold Render free-tier instance can take 30-60s to respond (see
    // .github/workflows/keep-alive.yml) — long enough that an impatient
    // user backing out mid-save looks like "nothing happened", when the
    // request actually completes moments later on the server. If they then
    // retry, that's a genuine duplicate (found for real, 2026-08-11:
    // two properties from one intended create). Blocking pop while saving
    // makes that failure mode impossible instead of just less likely.
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit property' : 'Add property')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Property name'),
                onChanged: _onNameChanged,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug (lowercase, hyphens only)',
                ),
                onChanged: (_) => _slugEdited = true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                    return 'Lowercase letters, numbers, hyphens only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _propertyTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'PG'),
              ),
              const SizedBox(height: 20),
              Text('Address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _line1,
                decoration: const InputDecoration(labelText: 'Address line 1'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line2,
                decoration: const InputDecoration(
                  labelText: 'Address line 2 (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _state,
                decoration: const InputDecoration(labelText: 'State'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pincode,
                decoration: const InputDecoration(labelText: 'Pincode'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Text('Billing', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentDueDay,
                decoration: const InputDecoration(
                  labelText: 'Rent due day of month (1-28)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 28) return 'Must be 1-28';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gracePeriodDays,
                decoration: const InputDecoration(
                  labelText: 'Grace period (days)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Must be 0 or more';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Create property'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
