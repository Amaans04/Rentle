import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';

const _invitableRoles = ['MANAGER', 'RECEPTIONIST', 'ACCOUNTANT', 'STAFF'];

class StaffInviteScreen extends ConsumerStatefulWidget {
  const StaffInviteScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<StaffInviteScreen> createState() => _StaffInviteScreenState();
}

class _StaffInviteScreenState extends ConsumerState<StaffInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = 'STAFF';
  final Set<String> _selectedPropertyIds = {};
  bool _saving = false;
  bool _sent = false;

  Future<void> _invite() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/organizations/${widget.orgId}/staff/invite',
        data: {
          'email': _email.text.trim(),
          'intendedRole': _role,
          'intendedPropertyIds': _selectedPropertyIds.toList(),
        },
      );
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider(widget.orgId));

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Invite staff')),
        body: _sent ? _buildSentView() : _buildForm(properties),
      ),
    );
  }

  Widget _buildSentView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read,
              color: context.semanticColors.success,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Invitation sent to ${_email.text.trim()}. They\'ll get access as soon as they accept it and sign in.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Property>> properties) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: _invitableRoles
                .map(
                  (r) => DropdownMenuItem(value: r, child: Text(titleCase(r))),
                )
                .toList(),
            onChanged: (v) => setState(() => _role = v!),
          ),
          const SizedBox(height: 20),
          Text(
            'Property access',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Text(
            'Leave all unchecked to grant access to every property (typical for a manager).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          AsyncValueView<List<Property>>(
            value: properties,
            data: (context, list) => Column(
              children: list
                  .map(
                    (p) => CheckboxListTile(
                      title: Text(p.name),
                      value: _selectedPropertyIds.contains(p.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedPropertyIds.add(p.id);
                        } else {
                          _selectedPropertyIds.remove(p.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _invite,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send invite'),
          ),
        ],
      ),
    );
  }
}
