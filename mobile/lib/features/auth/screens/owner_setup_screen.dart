import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/features/auth/providers/auth_provider.dart';
import 'package:rentle/repositories/auth_repository.dart';
import 'package:rentle/repositories/owner_repository.dart';

class OwnerSetupScreen extends ConsumerStatefulWidget {
  const OwnerSetupScreen({super.key});

  @override
  ConsumerState<OwnerSetupScreen> createState() => _OwnerSetupScreenState();
}

class _OwnerSetupScreenState extends ConsumerState<OwnerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _propertyController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _roomsController = TextEditingController();
  final _phoneController = TextEditingController();
  String _genderType = 'unisex';
  int _rentDueDate = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    final me = await ref.read(authStateProvider.future);
    if (me != null && me.user.phone.isNotEmpty) {
      _phoneController.text = me.user.phone;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(ownerRepositoryProvider).setupProperty(
            name: _nameController.text.trim(),
            propertyName: _propertyController.text.trim(),
            address: _addressController.text.trim(),
            city: _cityController.text.trim(),
            roomCount: int.parse(_roomsController.text.trim()),
            genderType: _genderType,
            rentDueDate: _rentDueDate,
            contactPhone: ref
                .read(authRepositoryProvider)
                .sanitizePhone(_phoneController.text),
          );
      await ref.read(authRepositoryProvider).saveTokensFromResponse(result);
      await ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RentleColors.teal,
          content: const Text('Property created! Welcome to Rentle 🎉'),
        ),
      );
      context.go('/owner/dashboard');
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
  void dispose() {
    _nameController.dispose();
    _propertyController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _roomsController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RentleAppBar(
        title: 'Set Up Your Property',
        fallbackRoute: '/welcome',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(_nameController, 'Your Name', required: true),
                  _field(_propertyController, 'Property Name', required: true),
                  _field(_addressController, 'Full Address',
                      required: true, maxLines: 3),
                  _field(_cityController, 'City', required: true),
                  _field(_roomsController, 'Number of Rooms',
                      required: true, keyboard: TextInputType.number),
                  DropdownButtonFormField<String>(
                    value: _genderType,
                    decoration: const InputDecoration(labelText: 'Gender Type'),
                    items: const [
                      DropdownMenuItem(value: 'boys', child: Text('Boys')),
                      DropdownMenuItem(value: 'girls', child: Text('Girls')),
                      DropdownMenuItem(value: 'unisex', child: Text('Unisex')),
                    ],
                    onChanged: (v) => setState(() => _genderType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _rentDueDate,
                    decoration:
                        const InputDecoration(labelText: 'Rent Due Date'),
                    items: List.generate(
                      28,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}${_ordinal(i + 1)}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _rentDueDate = v!),
                  ),
                  const SizedBox(height: 12),
                  _field(_phoneController, 'Contact Phone',
                      required: true, keyboard: TextInputType.phone),
                  const SizedBox(height: 24),
                  RentleButton(
                    label: 'Create Property',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
