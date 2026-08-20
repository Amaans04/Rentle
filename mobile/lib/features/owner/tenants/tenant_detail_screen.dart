import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/document_upload.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/models/tenancy_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/documents_section.dart';
import '../../../core/widgets/status_badge.dart';
import '../owner_providers.dart';
import 'tenants_list_screen.dart' show tenancyStatusColor;

class TenantDetailScreen extends ConsumerStatefulWidget {
  const TenantDetailScreen({super.key, required this.orgId, required this.propertyId, required this.tenancy});

  final String orgId;
  final String propertyId;
  final Tenancy tenancy;

  @override
  ConsumerState<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends ConsumerState<TenantDetailScreen> {
  late Tenancy _tenancy = widget.tenancy;
  bool _busy = false;

  Future<void> _runAction(String path, {Map<String, dynamic>? data}) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch('/organizations/${widget.orgId}/$path', data: data ?? {});
      // The lifecycle PATCH endpoints return the bare updated row (no
      // user/bed/events includes) — refetch the full detail so the display
      // name, bed label, and timeline don't blank out after an action.
      final res = await api.dio.get('/organizations/${widget.orgId}/tenancies/${_tenancy.id}');
      setState(() => _tenancy = Tenancy.fromJson(res.data['data'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transfer() async {
    final key = (orgId: widget.orgId, propertyId: widget.propertyId);
    final beds = await ref.read(vacantBedsProvider(key).future);
    if (!mounted) return;
    if (beds.isEmpty) {
      showErrorSnackBar(context, 'No vacant beds to transfer to.');
      return;
    }
    final selected = await showDialog<Bed>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transfer to which bed?'),
        children: beds
            .map((b) => SimpleDialogOption(onPressed: () => Navigator.of(context).pop(b), child: Text('Bed ${b.bedLabel}')))
            .toList(),
      ),
    );
    if (selected != null) {
      await _runAction('tenancies/${_tenancy.id}/transfer', data: {'newBedId': selected.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tenancy;
    return Scaffold(
      appBar: AppBar(title: Text(t.displayName)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [StatusBadge(label: titleCase(t.status), color: tenancyStatusColor(context, t.status))],
                    ),
                    const SizedBox(height: 12),
                    _row('Bed', t.bedLabel ?? '—'),
                    _row('Rent', '${formatMoney(t.rentAmount)}/mo'),
                    _row('Deposit', formatMoney(t.depositAmount)),
                    if (t.tenantEmail != null) _row('Email', t.tenantEmail!),
                    if (t.tenantPhone != null) _row('Phone', t.tenantPhone!),
                    _row('Move-in', formatDate(t.moveInDate)),
                    if (t.noticeDate != null) _row('Notice given', formatDate(t.noticeDate)),
                    if (t.moveOutDate != null) _row('Move-out', formatDate(t.moveOutDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (t.status == 'PENDING_ONBOARDING')
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _runAction('tenancies/${t.id}/activate'),
                    icon: const Icon(Icons.check),
                    label: const Text('Activate'),
                  ),
                if (t.status == 'ACTIVE')
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _runAction('tenancies/${t.id}/notice'),
                    icon: const Icon(Icons.event_note),
                    label: const Text('Give notice'),
                  ),
                if (t.status == 'ACTIVE')
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _transfer,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Transfer bed'),
                  ),
                if (t.status == 'PENDING_ONBOARDING' || t.status == 'ACTIVE' || t.status == 'NOTICE_GIVEN')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: _busy ? null : () => _confirmMoveOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Move out'),
                  ),
              ],
            ),
            if (t.events.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...t.events.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(titleCase(e.type)),
                  subtitle: Text(formatDate(e.createdAt)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            DocumentsSection(
              documents: ref.watch(tenancyDocumentsProvider((orgId: widget.orgId, tenancyId: t.id))),
              onUpload: () async {
                final uploaded = await pickAndUploadDocument(
                  context: context,
                  ref: ref,
                  requestPath: '/organizations/${widget.orgId}/tenancies/${t.id}/documents',
                  confirmPath: '/organizations/${widget.orgId}/tenancies/${t.id}/documents/confirm',
                );
                if (uploaded) ref.invalidate(tenancyDocumentsProvider((orgId: widget.orgId, tenancyId: t.id)));
              },
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmMoveOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move out this tenant?'),
        content: const Text('This frees up their bed and archives the tenancy.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Move out')),
        ],
      ),
    );
    if (confirmed == true) await _runAction('tenancies/${_tenancy.id}/move-out');
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
