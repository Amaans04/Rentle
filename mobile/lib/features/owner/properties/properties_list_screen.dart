import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';
import '../staff/staff_list_screen.dart';
import 'property_form_screen.dart';
import 'property_workspace_screen.dart';

class PropertiesListScreen extends ConsumerWidget {
  const PropertiesListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Staff',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StaffListScreen(orgId: orgId))),
          ),
          const ClerkUserButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<List<Property>>(
        value: properties,
        onRetry: () => ref.invalidate(propertiesProvider(orgId)),
        data: (context, list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No properties yet.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Add your first PG property to get started.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(propertiesProvider(orgId).future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final property = list[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: Text(property.name),
                  subtitle: Text(property.address.oneLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => PropertyWorkspaceScreen(orgId: orgId, property: property)));
                    ref.invalidate(propertiesProvider(orgId));
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => PropertyFormScreen(orgId: orgId)));
          if (created == true) ref.invalidate(propertiesProvider(orgId));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add property'),
      ),
    );
  }
}
