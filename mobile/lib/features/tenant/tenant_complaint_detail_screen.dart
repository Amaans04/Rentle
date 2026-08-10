import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/models/complaint_models.dart';
import '../../core/providers/api_providers.dart';
import '../../core/widgets/async_value_view.dart';
import '../owner/complaints/complaints_list_screen.dart' show complaintStatusColor;
import 'tenant_providers.dart';

class TenantComplaintDetailScreen extends ConsumerStatefulWidget {
  const TenantComplaintDetailScreen({super.key, required this.orgId, required this.complaintId});

  final String orgId;
  final String complaintId;

  @override
  ConsumerState<TenantComplaintDetailScreen> createState() => _TenantComplaintDetailScreenState();
}

class _TenantComplaintDetailScreenState extends ConsumerState<TenantComplaintDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  TenantComplaintKey get _key => (orgId: widget.orgId, complaintId: widget.complaintId);

  Future<void> _postComment() async {
    if (_comment.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/organizations/${widget.orgId}/tenant/complaints/${widget.complaintId}/comments',
        data: {'content': _comment.text.trim()},
      );
      _comment.clear();
      ref.invalidate(tenantComplaintDetailProvider(_key));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = ref.watch(tenantComplaintDetailProvider(_key));

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint')),
      body: AsyncValueView<Complaint>(
        value: complaint,
        onRetry: () => ref.invalidate(tenantComplaintDetailProvider(_key)),
        data: (context, c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Chip(
              label: Text(titleCase(c.status)),
              backgroundColor: complaintStatusColor(c.status).withValues(alpha: 0.15),
              labelStyle: TextStyle(color: complaintStatusColor(c.status)),
            ),
            const SizedBox(height: 12),
            Text(c.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${titleCase(c.category)} · ${formatDate(c.createdAt)}'),
            const SizedBox(height: 12),
            Text(c.description),
            const SizedBox(height: 20),
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            ...c.comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.content),
                    Text(formatDate(comment.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _comment, decoration: const InputDecoration(hintText: 'Add a comment'))),
                IconButton(onPressed: _sending ? null : _postComment, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
