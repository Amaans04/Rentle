import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/complaint_models.dart';
import '../../../core/models/user_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';
import 'complaint_transitions.dart';
import 'complaints_list_screen.dart' show complaintStatusColor, priorityColor;

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.orgId, required this.complaintId});

  final String orgId;
  final String complaintId;

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _comment = TextEditingController();
  bool _busy = false;

  ComplaintDetailKey get _key => (orgId: widget.orgId, complaintId: widget.complaintId);

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch('/organizations/${widget.orgId}/complaints/${widget.complaintId}/status', data: {'status': status});
      ref.invalidate(complaintDetailProvider(_key));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(String? userId) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.patch('/organizations/${widget.orgId}/complaints/${widget.complaintId}/assign', data: {'assigneeId': userId});
      ref.invalidate(complaintDetailProvider(_key));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postComment() async {
    if (_comment.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/organizations/${widget.orgId}/complaints/${widget.complaintId}/comments',
        data: {'content': _comment.text.trim()},
      );
      _comment.clear();
      ref.invalidate(complaintDetailProvider(_key));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = ref.watch(complaintDetailProvider(_key));
    final members = ref.watch(orgMembersProvider(widget.orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint')),
      body: AsyncValueView<Complaint>(
        value: complaint,
        onRetry: () => ref.invalidate(complaintDetailProvider(_key)),
        data: (context, c) {
          final nextStatuses = complaintAllowedTransitions[c.status] ?? const [];
          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(titleCase(c.status)),
                      backgroundColor: complaintStatusColor(context, c.status).withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: complaintStatusColor(context, c.status)),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(c.priority),
                      backgroundColor: priorityColor(context, c.priority).withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: priorityColor(context, c.priority)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(c.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${titleCase(c.category)} · reported by ${c.reporterName ?? 'Tenant'} · ${formatDate(c.createdAt)}'),
                const SizedBox(height: 12),
                Text(c.description),
                const SizedBox(height: 20),
                Text('Assignee', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                AsyncValueView<List<OrgMemberSummary>>(
                  value: members,
                  data: (context, list) => DropdownButtonFormField<String?>(
                    initialValue: c.assigneeId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned')),
                      ...list.map((m) => DropdownMenuItem(value: m.userId, child: Text('${m.name} (${m.role})'))),
                    ],
                    onChanged: _assign,
                  ),
                ),
                if (nextStatuses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Change status', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: nextStatuses
                        .map((s) => OutlinedButton(onPressed: () => _setStatus(s), child: Text(titleCase(s))))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
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
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        decoration: const InputDecoration(hintText: 'Add a comment'),
                      ),
                    ),
                    IconButton(onPressed: _postComment, icon: const Icon(Icons.send)),
                  ],
                ),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          );
        },
      ),
    );
  }
}
