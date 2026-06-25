import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/tenant_model.dart';
import 'package:rentle/repositories/owner_repository.dart';

class OwnerAddChargeScreen extends ConsumerStatefulWidget {
  const OwnerAddChargeScreen({
    super.key,
    required this.tenant,
  });

  final TenantModel tenant;

  @override
  ConsumerState<OwnerAddChargeScreen> createState() =>
      _OwnerAddChargeScreenState();
}

class _OwnerAddChargeScreenState extends ConsumerState<OwnerAddChargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _chargeType = 'fine';
  bool _loading = false;

  static const _chargeTypes = [
    ('fine', 'Fine / Penalty'),
    ('electricity', 'Electricity'),
    ('water', 'Water'),
    ('food', 'Food'),
    ('laundry', 'Laundry'),
    ('maintenance', 'Maintenance'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(ownerRepositoryProvider).createCharge(
            tenantId: widget.tenant.uid,
            chargeType: _chargeType,
            description: _descriptionController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: RentleColors.teal,
            content: Text('Charge added. Tenant can pay via UPI.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;

    return Scaffold(
      appBar: const RentleAppBar(title: 'Add Charge'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tenant.name ?? 'Tenant',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Room ${tenant.roomNumber ?? '-'}',
                style: GoogleFonts.inter(color: RentleColors.charcoal),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _chargeType,
                decoration: const InputDecoration(labelText: 'Charge Type'),
                items: _chargeTypes
                    .map(
                      (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _chargeType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Late payment fine for March',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Tenant will see this charge and can pay via UPI using your configured UPI ID.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: RentleColors.charcoal.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              RentleButton(
                label: 'Add Charge',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
