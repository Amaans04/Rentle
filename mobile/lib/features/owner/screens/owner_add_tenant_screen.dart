import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/payment_utils.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/owner/screens/owner_rooms_screen.dart';
import 'package:rentle/features/owner/screens/owner_tenants_screen.dart';
import 'package:rentle/models/room_model.dart';
import 'package:rentle/repositories/auth_repository.dart';
import 'package:rentle/repositories/owner_repository.dart';

class OwnerAddTenantScreen extends ConsumerStatefulWidget {
  const OwnerAddTenantScreen({
    super.key,
    this.initialName,
    this.initialPhone,
    this.initialRoomId,
  });

  final String? initialName;
  final String? initialPhone;
  final String? initialRoomId;

  @override
  ConsumerState<OwnerAddTenantScreen> createState() =>
      _OwnerAddTenantScreenState();
}

class _OwnerAddTenantScreenState extends ConsumerState<OwnerAddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  RoomModel? _selectedRoom;
  DateTime _moveInDate = DateTime.now();
  late final TextEditingController _rentController;
  final _depositController = TextEditingController(text: '0');
  bool _loading = false;
  List<RoomModel> _availableRooms = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _rentController = TextEditingController();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await ref.read(ownerRoomsProvider.future);
      final available =
          rooms.where((r) => r.status == 'vacant' || r.status == 'partial').toList();
      if (!mounted) return;
      setState(() {
        _availableRooms = available;
        if (available.isEmpty) return;

        RoomModel? preselected;
        if (widget.initialRoomId != null) {
          for (final r in available) {
            if (r.roomId == widget.initialRoomId) {
              preselected = r;
              break;
            }
          }
        }

        _selectedRoom = preselected ?? available.first;
        _rentController.text =
            _selectedRoom!.rentAmount.toStringAsFixed(0);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission is required to pick from phonebook'),
        ),
      );
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );

    final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) =>
          (a.displayName ?? '').compareTo(b.displayName ?? ''));

    if (!mounted) return;

    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = withPhone.where((c) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              final name = (c.displayName ?? '').toLowerCase();
              final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
              return name.contains(q) || phone.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Select Contact',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search contacts',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setSheetState(() => query = v.toLowerCase()),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No contacts with phone numbers',
                                style: GoogleFonts.inter(),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final contact = filtered[index];
                                final phone = ref
                                    .read(authRepositoryProvider)
                                    .sanitizePhone(
                                      contact.phones.first.number,
                                    );
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      (contact.displayName ?? '?')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(contact.displayName ?? 'Unknown'),
                                  subtitle: Text(phone),
                                  onTap: () => Navigator.pop(ctx, contact),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (picked == null) return;

    final authRepo = ref.read(authRepositoryProvider);
    final phone = authRepo.sanitizePhone(picked.phones.first.number);
    setState(() {
      _nameController.text = picked.displayName ?? '';
      _phoneController.text = phone;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a vacant or partial room first')),
      );
      return;
    }

    final authRepo = ref.read(authRepositoryProvider);
    final phone = authRepo.sanitizePhone(_phoneController.text);
    if (!authRepo.isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(ownerRepositoryProvider).inviteTenant(
            name: _nameController.text.trim(),
            phone: phone,
            roomId: _selectedRoom!.roomId,
            moveInDate: _moveInDate,
            rentAmount: double.tryParse(_rentController.text) ?? 0,
            depositAmount: double.tryParse(_depositController.text) ?? 0,
          );

      if (!mounted) return;
      ref.invalidate(ownerTenantsProvider);
      ref.invalidate(ownerRoomsProvider);

      await PaymentUtils.launchWhatsApp(
        phone,
        'Hi ${_nameController.text.trim()}, you have been invited to join '
        'Room ${_selectedRoom!.roomNumber} on Rentle. Install the app and sign up '
        'with +91$phone to accept.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RentleColors.teal,
          content: const Text('Invite sent!'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RentleAppBar(title: 'Add Tenant'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FadeSlideIn(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tenant details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickContact,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.contacts_rounded, size: 18),
                    label: const Text('Contacts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                  counterText: '',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final phone =
                      ref.read(authRepositoryProvider).sanitizePhone(v ?? '');
                  if (!ref.read(authRepositoryProvider).isValidPhone(phone)) {
                    return 'Enter a valid 10-digit number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Text(
                'Room assignment',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_availableRooms.isEmpty)
              Text(
                'No vacant or partial rooms. Add a room first.',
                style: GoogleFonts.inter(color: RentleColors.coral),
              )
            else
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: DropdownButtonFormField<RoomModel>(
                  value: _selectedRoom,
                  decoration: const InputDecoration(labelText: 'Room'),
                  items: _availableRooms
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            'Room ${r.roomNumber} · ${r.currentOccupancy}/${r.sharingCapacity} beds',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (room) {
                    setState(() {
                      _selectedRoom = room;
                      _rentController.text =
                          room?.rentAmount.toStringAsFixed(0) ?? '';
                    });
                  },
                ),
              ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Move-in Date'),
                subtitle: Text(DateFormat.yMMMd().format(_moveInDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _moveInDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _moveInDate = picked);
                  }
                },
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: TextFormField(
                controller: _rentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Rent Amount (₹)',
                  helperText: _selectedRoom != null
                      ? 'Default from room: ₹${_selectedRoom!.rentAmount.toStringAsFixed(0)}'
                      : null,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Rent is required' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: TextFormField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Deposit Amount (₹)',
                ),
              ),
            ),
            const SizedBox(height: 32),
            RentleButton(
              label: 'Send Invite',
              loading: _loading,
              onPressed: _availableRooms.isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
