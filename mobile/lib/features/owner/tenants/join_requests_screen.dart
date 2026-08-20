import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/discovery_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
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
          return const EmptyState(
            icon: Icons.person_add_alt,
            title: 'No pending requests',
            subtitle: 'Prospective tenants who find this PG via search will show up here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(joinRequestsProvider(key).future),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final request = list[index];
              return StaggeredEntrance(
                index: index,
                child: AppListCard(
                  leadingIcon: Icons.person_add_alt,
                  title: request.requesterDisplayName,
                  subtitle: request.message?.isNotEmpty == true ? request.message! : 'Requested ${formatDate(request.createdAt)}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                        tooltip: 'Reject',
                        onPressed: () => _reject(context, ref, request, key),
                      ),
                      IconButton(
                        icon: Icon(Icons.check_circle, color: context.semanticColors.success),
                        tooltip: 'Approve',
                        onPressed: () => _approve(context, ref, request, key),
                      ),
                    ],
                  ),
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
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
    final saving = ValueNotifier(false);
    final approved = await AppBottomSheet.show<bool>(
      context,
      title: 'Approve ${request.requesterDisplayName}',
      saving: saving,
      builder: (_) => _ApproveJoinRequestSheet(orgId: orgId, property: property, request: request, saving: saving),
    ).whenComplete(saving.dispose);
    if (approved == true) ref.invalidate(joinRequestsProvider(key));
  }
}

class _ApproveJoinRequestSheet extends ConsumerStatefulWidget {
  const _ApproveJoinRequestSheet({required this.orgId, required this.property, required this.request, required this.saving});

  final String orgId;
  final Property property;
  final JoinRequest request;
  final ValueNotifier<bool> saving;

  @override
  ConsumerState<_ApproveJoinRequestSheet> createState() => _ApproveJoinRequestSheetState();
}

class _ApproveJoinRequestSheetState extends ConsumerState<_ApproveJoinRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  Bed? _selectedBed;
  final _rentAmount = TextEditingController();
  final _depositAmount = TextEditingController(text: '0');

  @override
  void dispose() {
    _rentAmount.dispose();
    _depositAmount.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_selectedBed == null) {
      showErrorSnackBar(context, 'Pick a vacant bed first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    widget.saving.value = true;
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
      widget.saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id);
    final vacantBeds = ref.watch(vacantBedsProvider(key));

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          ValueListenableBuilder<bool>(
            valueListenable: widget.saving,
            builder: (context, saving, _) => FilledButton(
              onPressed: saving ? null : _approve,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Approve'),
            ),
          ),
        ],
      ),
    );
  }
}
