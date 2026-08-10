import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/models/user_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../owner_providers.dart';

const _allRoles = ['OWNER', 'MANAGER', 'RECEPTIONIST', 'ACCOUNTANT', 'STAFF'];

class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({
    super.key,
    required this.orgId,
    required this.member,
  });

  final String orgId;
  final OrgMember member;

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  late String _role = widget.member.role;
  late final Set<String> _selectedPropertyIds = {...widget.member.propertyIds};
  final _salary = TextEditingController();
  DateTime? _joinDate;
  bool _saving = false;
  bool _profileLoaded = false;

  Future<void> _saveMembership() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch(
        '/organizations/${widget.orgId}/members/${widget.member.id}',
        data: {'role': _role, 'propertyIds': _selectedPropertyIds.toList()},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put(
        '/organizations/${widget.orgId}/members/${widget.member.id}/staff-profile',
        data: {
          if (_salary.text.trim().isNotEmpty)
            'salary': double.tryParse(_salary.text.trim()),
          if (_joinDate != null) 'joinDate': _joinDate!.toIso8601String(),
        },
      );
      if (mounted) {
        ref.invalidate(
          staffProfileProvider((
            orgId: widget.orgId,
            memberId: widget.member.id,
          )),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Deactivate ${widget.member.displayName}?',
      message:
          'They\'ll lose access to this organization immediately. This can be undone by inviting them again.',
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete(
        '/organizations/${widget.orgId}/members/${widget.member.id}',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider(widget.orgId));
    final profile = ref.watch(
      staffProfileProvider((orgId: widget.orgId, memberId: widget.member.id)),
    );

    profile.whenData((p) {
      if (!_profileLoaded && p != null) {
        _profileLoaded = true;
        if (p.salary != null) _salary.text = p.salary!.toStringAsFixed(0);
        _joinDate = p.joinDate;
      }
    });

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.member.displayName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.member.userEmail ?? widget.member.userPhone ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _allRoles
                  .map(
                    (r) =>
                        DropdownMenuItem(value: r, child: Text(titleCase(r))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 16),
            Text(
              'Property access',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Text(
              'No properties checked = access to every property.',
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
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _saveMembership,
              child: const Text('Save role & access'),
            ),
            const Divider(height: 40),
            Text(
              'Staff profile',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _salary,
              decoration: const InputDecoration(
                labelText: 'Salary (₹/month, optional)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Join date'),
              subtitle: Text(
                _joinDate == null ? 'Not set' : formatDate(_joinDate),
              ),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _joinDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _joinDate = picked);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : _saveProfile,
              child: const Text('Save staff profile'),
            ),
            const Divider(height: 40),
            if (widget.member.isActive)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _saving ? null : _deactivate,
                icon: const Icon(Icons.person_off),
                label: const Text('Deactivate'),
              )
            else
              const Text(
                'This member is inactive.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
