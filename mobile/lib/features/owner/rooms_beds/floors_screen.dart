import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../owner_providers.dart';
import 'floor_form_sheet.dart';
import 'rooms_screen.dart';

class FloorsScreen extends ConsumerWidget {
  const FloorsScreen({super.key, required this.orgId, required this.property, required this.building});

  final String orgId;
  final Property property;
  final Building building;

  Future<void> _edit(BuildContext context, WidgetRef ref, BuildingKey key, Floor floor) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FloorFormSheet(orgId: orgId, existing: floor),
    );
    if (edited == true) ref.invalidate(floorsProvider(key));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BuildingKey key, Floor floor) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this floor?',
      message: '"${floor.name}" and its rooms/beds stay in records but are removed from view.',
    );
    if (!confirmed) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/$orgId/floors/${floor.id}');
      ref.invalidate(floorsProvider(key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (orgId: orgId, buildingId: building.id);
    final floors = ref.watch(floorsProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(building.name)),
      body: AsyncValueView<List<Floor>>(
        value: floors,
        onRetry: () => ref.invalidate(floorsProvider(key)),
        data: (context, list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No floors yet. Add one to start adding rooms.', textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(floorsProvider(key).future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final floor = list[index];
                return ListTile(
                  leading: const Icon(Icons.layers),
                  title: Text(floor.name),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit' ? _edit(context, ref, key, floor) : _delete(context, ref, key, floor),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomsScreen(orgId: orgId, property: property, building: building, floor: floor),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => FloorFormSheet(orgId: orgId, buildingId: building.id),
          );
          if (created == true) ref.invalidate(floorsProvider(key));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add floor'),
      ),
    );
  }
}
