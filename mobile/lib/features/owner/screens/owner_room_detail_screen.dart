import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/owner/screens/owner_rooms_screen.dart';
import 'package:rentle/features/owner/screens/owner_tenants_screen.dart';
import 'package:rentle/models/room_model.dart';
import 'package:rentle/models/tenant_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

class OwnerRoomDetailScreen extends ConsumerStatefulWidget {
  const OwnerRoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<OwnerRoomDetailScreen> createState() =>
      _OwnerRoomDetailScreenState();
}

class _OwnerRoomDetailScreenState extends ConsumerState<OwnerRoomDetailScreen> {
  bool _deleting = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'vacant':
        return RentleColors.teal;
      case 'partial':
        return RentleColors.amber;
      case 'full':
        return RentleColors.coral;
      default:
        return RentleColors.charcoal;
    }
  }

  bool _canAddTenant(RoomModel room) =>
      room.currentOccupancy < room.sharingCapacity;

  bool _canDelete(RoomModel room) => room.currentOccupancy == 0;

  void _showEditRoomSheet(RoomModel room) {
    final numberController = TextEditingController(text: room.roomNumber);
    final rentController =
        TextEditingController(text: room.rentAmount.toStringAsFixed(0));
    final mrpController =
        TextEditingController(text: room.mrpAmount.toStringAsFixed(0));
    final capacityController =
        TextEditingController(text: room.sharingCapacity.toString());
    final floorController =
        TextEditingController(text: room.floor?.toString() ?? '');
    String roomType = room.roomType;
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Room',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: numberController,
                      decoration: const InputDecoration(labelText: 'Room Number'),
                    ),
                    DropdownButtonFormField<String>(
                      value: roomType,
                      decoration: const InputDecoration(labelText: 'Room Type'),
                      items: const [
                        DropdownMenuItem(value: 'single', child: Text('Single')),
                        DropdownMenuItem(value: 'double', child: Text('Double')),
                        DropdownMenuItem(value: 'triple', child: Text('Triple')),
                        DropdownMenuItem(
                          value: 'dormitory',
                          child: Text('Dormitory'),
                        ),
                      ],
                      onChanged: (v) => setSheetState(() => roomType = v!),
                    ),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Capacity',
                        helperText:
                            'Min ${room.currentOccupancy} (current occupancy)',
                      ),
                    ),
                    TextField(
                      controller: floorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Floor'),
                    ),
                    TextField(
                      controller: rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rent Amount'),
                    ),
                    TextField(
                      controller: mrpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'MRP Amount'),
                    ),
                    const SizedBox(height: 16),
                    RentleButton(
                      label: 'Save Changes',
                      loading: saving,
                      onPressed: saving
                          ? null
                          : () async {
                              final capacity =
                                  int.tryParse(capacityController.text) ?? 1;
                              if (capacity < room.currentOccupancy) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Capacity cannot be less than current occupancy (${room.currentOccupancy})',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => saving = true);
                              try {
                                final data = <String, dynamic>{
                                  'roomNumber': numberController.text.trim(),
                                  'roomType': roomType,
                                  'sharingCapacity': capacity,
                                  'rentAmount':
                                      double.tryParse(rentController.text) ?? 0,
                                  'mrpAmount':
                                      double.tryParse(mrpController.text) ?? 0,
                                };
                                final floor = int.tryParse(floorController.text);
                                if (floor != null) data['floor'] = floor;

                                await ref
                                    .read(ownerRepositoryProvider)
                                    .updateRoom(room.roomId, data);
                                ref.invalidate(ownerRoomsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Room updated'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(friendlyApiError(e)),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      numberController.dispose();
      rentController.dispose();
      mrpController.dispose();
      capacityController.dispose();
      floorController.dispose();
    });
  }

  Future<void> _confirmDelete(RoomModel room) async {
    if (!_canDelete(room)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete a room with tenants. Move all tenants out first.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Room ${room.roomNumber}?'),
        content: const Text(
          'This will permanently remove the room. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: RentleColors.coral),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(ownerRepositoryProvider).deleteRoom(room.roomId);
      ref.invalidate(ownerRoomsProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room ${room.roomNumber} deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(ownerRoomsProvider);
    final tenants = ref.watch(ownerTenantsProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Room Detail'),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(friendlyApiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          final room = list.cast<RoomModel?>().firstWhere(
                (r) => r?.roomId == widget.roomId,
                orElse: () => null,
              );
          if (room == null) {
            return const Center(child: Text('Room not found'));
          }

          final roomTenants = tenants.maybeWhen(
            data: (all) => all
                .where(
                  (t) => t.roomId == widget.roomId && t.status == 'active',
                )
                .toList(),
            orElse: () => <TenantModel>[],
          );

          final canAdd = _canAddTenant(room);
          final canDelete = _canDelete(room);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Room ${room.roomNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(room.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    room.status,
                    style: GoogleFonts.inter(
                      color: _statusColor(room.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'Type', value: room.roomType),
                _DetailRow(
                  label: 'Occupancy',
                  value: '${room.currentOccupancy}/${room.sharingCapacity} beds',
                ),
                if (room.floor != null)
                  _DetailRow(label: 'Floor', value: room.floor.toString()),
                _DetailRow(
                  label: 'Rent',
                  value: '₹${room.rentAmount.toInt()}/mo',
                ),
                _DetailRow(
                  label: 'MRP',
                  value: '₹${room.mrpAmount.toInt()}/mo',
                ),
                if (roomTenants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tenants in this room',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...roomTenants.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PressableCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  RentleColors.trustBlue.withValues(alpha: 0.15),
                              child: Text(
                                (t.name?.isNotEmpty == true
                                        ? t.name![0]
                                        : '?')
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: RentleColors.trustBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name ?? 'Tenant',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (t.phone != null)
                                    Text(
                                      t.phone!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: RentleColors.charcoal
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                RentleButton(
                  label: canAdd ? 'Add Tenant to Room' : 'Room is Full',
                  color: RentleColors.trustBlue,
                  enabled: canAdd,
                  onPressed: canAdd
                      ? () => context.push(
                            '/owner/tenants/add',
                            extra: {'roomId': room.roomId},
                          )
                      : null,
                ),
                const SizedBox(height: 12),
                RentleButton(
                  label: 'Edit Room Details',
                  color: RentleColors.trustBlue,
                  onPressed: () => _showEditRoomSheet(room),
                ),
                const SizedBox(height: 12),
                RentleButton(
                  label: 'Delete Room',
                  color: RentleColors.coral,
                  loading: _deleting,
                  enabled: canDelete && !_deleting,
                  onPressed: canDelete && !_deleting
                      ? () => _confirmDelete(room)
                      : null,
                ),
                if (!canDelete) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Move all tenants out before you can delete this room.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: RentleColors.charcoal.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: RentleColors.charcoal.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
