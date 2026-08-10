import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/discovery_models.dart';
import '../../core/providers/api_providers.dart';
import '../../core/tenant_prefs.dart';
import '../../core/widgets/async_value_view.dart';
import 'discover_pg_screen.dart';
import 'tenant_providers.dart';

/// Shown while a submitted join request is PENDING, and to resolve it once
/// it isn't. No fixed deadline like register_pg_screen's webhook-lag
/// polling — a PENDING request is genuinely waiting on the owner's own
/// timeline, so this polls indefinitely (while the screen is visible) and
/// otherwise just reflects whatever GET .../mine currently says.
class JoinRequestStatusScreen extends ConsumerStatefulWidget {
  const JoinRequestStatusScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<JoinRequestStatusScreen> createState() => _JoinRequestStatusScreenState();
}

class _JoinRequestStatusScreenState extends ConsumerState<JoinRequestStatusScreen> {
  Timer? _poll;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => ref.invalidate(myJoinRequestsProvider(widget.orgId)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _handleResolved(JoinRequest request) async {
    switch (request.status) {
      case 'APPROVED':
        _poll?.cancel();
        await TenantPrefs.setOrgId(widget.orgId);
        await TenantPrefs.clearPendingJoinOrgId();
        if (mounted) context.go('/tenant/${widget.orgId}/home');
      case 'REJECTED':
      case 'CANCELLED':
        _poll?.cancel();
      default:
        break;
    }
  }

  Future<void> _cancel(String requestId) async {
    setState(() => _cancelling = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.dio.patch('/organizations/${widget.orgId}/join-requests/$requestId/cancel');
      await TenantPrefs.clearPendingJoinOrgId();
      _poll?.cancel();
      if (mounted) ref.invalidate(myJoinRequestsProvider(widget.orgId));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(myJoinRequestsProvider(widget.orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Your request')),
      body: AsyncValueView<List<JoinRequest>>(
        value: requests,
        onRetry: () => ref.invalidate(myJoinRequestsProvider(widget.orgId)),
        data: (context, list) {
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No request found — it may have already been resolved.', textAlign: TextAlign.center),
            );
          }
          final request = list.first; // server orders newest first
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleResolved(request));

          return switch (request.status) {
            'PENDING' => _pendingView(request),
            'REJECTED' => _rejectedView(request),
            'CANCELLED' => _cancelledView(),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _pendingView(JoinRequest request) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Waiting for ${request.propertyName ?? "the owner"} to approve your request',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "We'll take you straight in once it's approved. No need to keep this screen open — check back anytime.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _cancelling ? null : () => _cancel(request.id),
              child: _cancelling
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Cancel request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rejectedView(JoinRequest request) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "Your request to ${request.propertyName ?? 'that PG'} wasn't accepted this time.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (request.responseNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('"${request.responseNote}"', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await TenantPrefs.clearPendingJoinOrgId();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushReplacement(MaterialPageRoute(builder: (_) => const DiscoverPgScreen()));
                }
              },
              child: const Text('Search again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This request was cancelled.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DiscoverPgScreen())),
              child: const Text('Search again'),
            ),
          ],
        ),
      ),
    );
  }
}
