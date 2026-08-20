import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_list_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../owner_providers.dart';
import 'building_form_sheet.dart';
import 'floors_screen.dart';

/// Root of the Rooms & Beds tab — buildings for this property. Drilling into
/// floors/rooms/beds happens via pushed screens (each owns its own AppBar +
/// FAB), this tab only owns the "add building" action via the workspace FAB.
class BuildingsScreen extends ConsumerWidget {
  const BuildingsScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  Future<void> _edit(BuildContext context, WidgetRef ref, PropertyKey key, Building building) async {
    final edited = await BuildingFormSheet.show(context, orgId: orgId, existing: building);
    if (edited == true) ref.invalidate(buildingsProvider(key));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PropertyKey key, Building building) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this building?',
      message: '"${building.name}" and its floors/rooms/beds stay in records but are removed from view.',
    );
    if (!confirmed) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/$orgId/buildings/${building.id}');
      ref.invalidate(buildingsProvider(key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (orgId: orgId, propertyId: property.id);
    final buildings = ref.watch(buildingsProvider(key));

    return AsyncValueView<List<Building>>(
      value: buildings,
      onRetry: () => ref.invalidate(buildingsProvider(key)),
      data: (context, list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.domain,
            title: 'No buildings yet',
            subtitle: 'Add one to start adding floors, rooms, and beds.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(buildingsProvider(key).future),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final building = list[index];
              return StaggeredEntrance(
                index: index,
                child: AppListCard(
                  leadingIcon: Icons.domain,
                  title: building.name,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit' ? _edit(context, ref, key, building) : _delete(context, ref, key, building),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FloorsScreen(orgId: orgId, property: property, building: building)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
