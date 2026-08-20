import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.large(
            title: const Text('Properties'),
            pinned: true,
            forceElevated: innerBoxIsScrolled,
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
        ],
        body: AsyncValueView<List<Property>>(
          value: properties,
          onRetry: () => ref.invalidate(propertiesProvider(orgId)),
          data: (context, list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.apartment,
                title: 'No properties yet',
                subtitle: 'Add your first PG property to get started.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(propertiesProvider(orgId).future),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final property = list[index];
                  return StaggeredEntrance(
                    index: index,
                    child: AppListCard(
                      leadingIcon: Icons.apartment,
                      title: property.name,
                      subtitle: property.address.oneLine,
                      onTap: () async {
                        await Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => PropertyWorkspaceScreen(orgId: orgId, property: property)));
                        ref.invalidate(propertiesProvider(orgId));
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
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
