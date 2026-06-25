import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/repositories/auth_repository.dart';

class OwnerPickContactScreen extends ConsumerStatefulWidget {
  const OwnerPickContactScreen({super.key});

  @override
  ConsumerState<OwnerPickContactScreen> createState() =>
      _OwnerPickContactScreenState();
}

class _OwnerPickContactScreenState extends ConsumerState<OwnerPickContactScreen> {
  List<Contact> _contacts = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );

    final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) =>
          (a.displayName ?? '').compareTo(b.displayName ?? ''));

    if (mounted) {
      setState(() {
        _contacts = withPhone;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final filtered = _contacts.where((c) {
      if (_query.isEmpty) return true;
      final name = (c.displayName ?? '').toLowerCase();
      final phone = c.phones.isNotEmpty
          ? authRepo.sanitizePhone(c.phones.first.number)
          : '';
      return name.contains(_query) || phone.contains(_query);
    }).toList();

    return Scaffold(
      appBar: const RentleAppBar(title: 'Pick from Contacts'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts found',
                          style: GoogleFonts.inter(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final contact = filtered[index];
                          final phone = authRepo.sanitizePhone(
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
                            subtitle: Text('+91 $phone'),
                            onTap: () {
                              context.push(
                                '/owner/tenants/add',
                                extra: {
                                  'name': contact.displayName ?? '',
                                  'phone': phone,
                                },
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
