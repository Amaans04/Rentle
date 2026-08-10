import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/discovery_models.dart';
import '../../core/providers/api_providers.dart';
import '../../core/tenant_prefs.dart';
import '../../core/widgets/async_value_view.dart';
import 'tenant_providers.dart';

/// The smaller alternative to full "browse nearby PGs" discovery: typed
/// search by name/city (no public map, no geolocation — see
/// docs/PROGRESS.md's 2026-08-10 scope note) + an owner-approval join
/// request, reusing the same PENDING_ONBOARDING Tenancy state the existing
/// invite-code flow produces.
class DiscoverPgScreen extends ConsumerStatefulWidget {
  const DiscoverPgScreen({super.key});

  @override
  ConsumerState<DiscoverPgScreen> createState() => _DiscoverPgScreenState();
}

class _DiscoverPgScreenState extends ConsumerState<DiscoverPgScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _requestToJoin(PropertyListing listing) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JoinRequestSheet(listing: listing),
    );
    if (message == null || !mounted) return; // sheet dismissed without submitting

    final api = ref.read(apiClientProvider);
    try {
      await api.dio.post(
        '/organizations/${listing.organizationId}/join-requests',
        data: {'propertyId': listing.propertyId, if (message.trim().isNotEmpty) 'message': message.trim()},
      );
      await TenantPrefs.setPendingJoinOrgId(listing.organizationId);
      // Route through `/` and let IdentityGate pick up the pending request
      // from TenantPrefs — same reasoning as register_pg_screen.dart's fix:
      // this call also collapses a multi-page stack in one `.go()`, so it
      // reuses IdentityGate's already-correct navigation instead of
      // computing the destination here directly.
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(propertySearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Find your PG')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'PG name or city',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().length < 2
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Type at least 2 characters to search.', textAlign: TextAlign.center),
                  )
                : AsyncValueView<List<PropertyListing>>(
                    value: results,
                    onRetry: () => ref.invalidate(propertySearchProvider(_query)),
                    data: (context, listings) {
                      if (listings.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "No PGs found with that name. Double-check the spelling, or ask the owner for an invite code instead.",
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: listings.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final listing = listings[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.apartment)),
                            title: Text(listing.name),
                            subtitle: Text('${listing.city}, ${listing.state}'),
                            trailing: FilledButton(onPressed: () => _requestToJoin(listing), child: const Text('Request')),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestSheet extends StatefulWidget {
  const _JoinRequestSheet({required this.listing});

  final PropertyListing listing;

  @override
  State<_JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<_JoinRequestSheet> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Request to join ${widget.listing.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('The owner will review your request and pick a bed for you.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Message (optional)',
              hintText: 'e.g. Looking for a single, move-in this month',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_message.text),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}
