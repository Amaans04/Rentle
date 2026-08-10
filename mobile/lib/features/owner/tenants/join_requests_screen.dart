import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/discovery_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';

/// Requests from prospective tenants who found this property via the public
/// search directory (see mobile/lib/features/tenant/discover_pg_screen.dart)
/// — org-wide on the server, filtered here to just this property, matching
/// the rest of PropertyWorkspaceScreen's per-property mental model.
class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (orgId: orgId, status: 'PENDING');
    final requests = ref.watch(joinRequestsProvider(key));

    return AsyncValueView<List<JoinRequest>>(
      value: requests,
      onRetry: () => ref.invalidate(joinRequestsProvider(key)),
      data: (context, all) {
        final list = all.where((r) => r.propertyId == property.id).toList();
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No pending requests. Prospective tenants who find this PG via search will show up here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(joinRequestsProvider(key).future),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final request = list[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
                title: Text(request.requesterDisplayName),
                subtitle: Text(
                  request.message?.isNotEmpty == true ? request.message! : 'Requested ${formatDate(request.createdAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      tooltip: 'Reject',
                      onPressed: () => _reject(context, ref, request, key),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Approve',
                      onPressed: () => _approve(context, ref, request, key),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, JoinRequest request, JoinRequestsKey key) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Reject ${request.requesterDisplayName}\'s request?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Note to include (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (note == null || !context.mounted) return; // dialog cancelled

    final api = ref.read(apiClientProvider);
    try {
      await api.dio.patch(
        '/organizations/$orgId/join-requests/${request.id}/reject',
        data: {if (note.trim().isNotEmpty) 'note': note.trim()},
      );
      ref.invalidate(joinRequestsProvider(key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, JoinRequest request, JoinRequestsKey key) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApproveJoinRequestSheet(orgId: orgId, property: property, request: request),
    );
    if (approved == true) ref.invalidate(joinRequestsProvider(key));
  }
}

class _ApproveJoinRequestSheet extends ConsumerStatefulWidget {
  const _ApproveJoinRequestSheet({required this.orgId, required this.property, required this.request});

  final String orgId;
  final Property property;
  final JoinRequest request;

  @override
  ConsumerState<_ApproveJoinRequestSheet> createState() => _ApproveJoinRequestSheetState();
}

class _ApproveJoinRequestSheetState extends ConsumerState<_ApproveJoinRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  Bed? _selectedBed;
  final _rentAmount = TextEditingController();
  final _depositAmount = TextEditingController(text: '0');
  bool _saving = false;

  Future<void> _approve() async {
    if (_selectedBed == null) {
      showErrorSnackBar(context, 'Pick a vacant bed first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch(
        '/organizations/${widget.orgId}/join-requests/${widget.request.id}/approve',
        data: {
          'bedId': _selectedBed!.id,
          'rentAmount': double.parse(_rentAmount.text.trim()),
          'depositAmount': double.parse(_depositAmount.text.trim()),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id);
    final vacantBeds = ref.watch(vacantBedsProvider(key));

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Approve ${widget.request.requesterDisplayName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Pick a bed and confirm rent — this creates their tenancy right away.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              AsyncValueView<List<Bed>>(
                value: vacantBeds,
                data: (context, beds) {
                  if (beds.isEmpty) {
                    return const Text('No vacant beds in this property right now.');
                  }
                  return DropdownButtonFormField<Bed>(
                    initialValue: _selectedBed,
                    decoration: const InputDecoration(labelText: 'Vacant bed'),
                    items: beds.map((b) => DropdownMenuItem(value: b, child: Text('Bed ${b.bedLabel}'))).toList(),
                    onChanged: (b) {
                      setState(() {
                        _selectedBed = b;
                        if (b?.rentAmount != null) _rentAmount.text = b!.rentAmount!.toStringAsFixed(0);
                      });
                    },
                  );
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
                controller: _depositAmount,
                decoration: const InputDecoration(labelText: 'Deposit amount (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _approve,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Approve'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
