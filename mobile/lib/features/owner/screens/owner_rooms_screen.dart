import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/room_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

final ownerRoomsProvider = FutureProvider.autoDispose<List<RoomModel>>((ref) {
  return ref.watch(ownerRepositoryProvider).getRooms();
});

class OwnerRoomsScreen extends ConsumerWidget {
  const OwnerRoomsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(ownerRoomsProvider);

    return Scaffold(
      appBar: const RentleAppBar(title: 'Rooms', showBack: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRoomSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('No rooms yet', style: GoogleFonts.inter()),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final room = list[index];
              return PressableCard(
                onTap: () => context.push('/owner/rooms/${room.roomId}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${room.roomNumber}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(room.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.status,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _statusColor(room.status),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${room.currentOccupancy}/${room.sharingCapacity} beds',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    Text(
                      '₹${room.rentAmount.toInt()}/mo',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: RentleColors.trustBlue,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddRoomSheet(BuildContext context, WidgetRef ref) {
    final numberController = TextEditingController();
    final rentController = TextEditingController();
    final mrpController = TextEditingController();
    final capacityController = TextEditingController(text: '1');
    String roomType = 'single';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Room', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
                  DropdownMenuItem(value: 'dormitory', child: Text('Dormitory')),
                ],
                onChanged: (v) => roomType = v!,
              ),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
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
                label: 'Add Room',
                onPressed: () async {
                  try {
                    await ref.read(ownerRepositoryProvider).createRoom({
                      'roomNumber': numberController.text.trim(),
                      'roomType': roomType,
                      'sharingCapacity':
                          int.tryParse(capacityController.text) ?? 1,
                      'rentAmount':
                          double.tryParse(rentController.text) ?? 0,
                      'mrpAmount': double.tryParse(mrpController.text) ?? 0,
                    });
                    ref.invalidate(ownerRoomsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
