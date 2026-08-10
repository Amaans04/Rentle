import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../owner_providers.dart';
import 'bed_form_sheet.dart';
import 'bed_status_sheet.dart';
import 'room_form_sheet.dart';

Color bedStatusColor(String status) {
  switch (status) {
    case 'VACANT':
      return Colors.green;
    case 'OCCUPIED':
      return Colors.blue;
    case 'RESERVED':
      return Colors.orange;
    case 'BLOCKED':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({
    super.key,
    required this.orgId,
    required this.property,
    required this.building,
    required this.floor,
  });

  final String orgId;
  final Property property;
  final Building building;
  final Floor floor;

  FloorRoomsKey get _key => (orgId: orgId, propertyId: property.id, floorId: floor.id);

  Future<void> _editRoom(BuildContext context, WidgetRef ref, Room room) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoomFormSheet(orgId: orgId, existing: room),
    );
    if (edited == true) ref.invalidate(roomsForFloorProvider(_key));
  }

  Future<void> _deleteRoom(BuildContext context, WidgetRef ref, Room room) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Room ${room.roomNumber}?',
      message: 'Its beds stay in records but are removed from view. A room with an occupied bed can\'t be deleted.',
    );
    if (!confirmed) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/$orgId/rooms/${room.id}');
      ref.invalidate(roomsForFloorProvider(_key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _editBed(BuildContext context, WidgetRef ref, Bed bed) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BedFormSheet(orgId: orgId, existing: bed),
    );
    if (edited == true) ref.invalidate(roomsForFloorProvider(_key));
  }

  Future<void> _deleteBed(BuildContext context, WidgetRef ref, Bed bed) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Bed ${bed.bedLabel}?',
      message: 'An occupied bed can\'t be deleted — move the tenant out first.',
    );
    if (!confirmed) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/$orgId/beds/${bed.id}');
      ref.invalidate(roomsForFloorProvider(_key));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsForFloorProvider(_key));

    return Scaffold(
      appBar: AppBar(title: Text('${building.name} · ${floor.name}')),
      body: AsyncValueView<List<Room>>(
        value: rooms,
        onRetry: () => ref.invalidate(roomsForFloorProvider(_key)),
        data: (context, list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No rooms on this floor yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(roomsForFloorProvider(_key).future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final room = list[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ExpansionTile(
                    title: Text('Room ${room.roomNumber}'),
                    subtitle: Text('${room.roomType} · ${room.sharingCapacity} bed(s) · ${formatMoney(room.rentAmount)}/mo'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'edit' ? _editRoom(context, ref, room) : _deleteRoom(context, ref, room),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit room')),
                        PopupMenuItem(value: 'delete', child: Text('Delete room')),
                      ],
                    ),
                    children: [
                      ...room.beds.map(
                        (bed) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: bedStatusColor(bed.status),
                            child: Text(bed.bedLabel, style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                          title: Text('Bed ${bed.bedLabel}'),
                          subtitle: Text(titleCase(bed.status)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              switch (value) {
                                case 'status':
                                  final changed = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => BedStatusSheet(orgId: orgId, bed: bed),
                                  );
                                  if (changed == true) ref.invalidate(roomsForFloorProvider(_key));
                                  break;
                                case 'edit':
                                  await _editBed(context, ref, bed);
                                  break;
                                case 'delete':
                                  await _deleteBed(context, ref, bed);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'status', child: Text('Change status')),
                              PopupMenuItem(value: 'edit', child: Text('Edit bed')),
                              PopupMenuItem(value: 'delete', child: Text('Delete bed')),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.bed),
                            label: const Text('Add bed'),
                            onPressed: () async {
                              final created = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => BedFormSheet(
                                  orgId: orgId,
                                  roomId: room.id,
                                  suggestedLabel: String.fromCharCode(65 + room.beds.length),
                                ),
                              );
                              if (created == true) ref.invalidate(roomsForFloorProvider(_key));
                            },
                          ),
                        ),
                      ),
                    ],
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
            builder: (_) => RoomFormSheet(orgId: orgId, propertyId: property.id, floorId: floor.id),
          );
          if (created == true) ref.invalidate(roomsForFloorProvider(_key));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
    );
  }
}
