import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/invite_code.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';

class TenantInviteScreen extends ConsumerStatefulWidget {
  const TenantInviteScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  ConsumerState<TenantInviteScreen> createState() => _TenantInviteScreenState();
}

class _TenantInviteScreenState extends ConsumerState<TenantInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  Bed? _selectedBed;
  final _rentAmount = TextEditingController();
  final _depositAmount = TextEditingController(text: '0');
  final _expiresInDays = TextEditingController(text: '7');
  bool _saving = false;
  String? _inviteCode;

  Future<void> _invite() async {
    if (_selectedBed == null) {
      showErrorSnackBar(context, 'Pick a vacant bed first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post(
        '/organizations/${widget.orgId}/properties/${widget.property.id}/tenancies/invite',
        data: {
          'bedId': _selectedBed!.id,
          'rentAmount': double.parse(_rentAmount.text.trim()),
          'depositAmount': double.parse(_depositAmount.text.trim()),
          'expiresInDays': int.parse(_expiresInDays.text.trim()),
        },
      );
      final token = (res.data['data'] as Map)['token'] as String;
      setState(() {
        _inviteCode = InviteCode(organizationId: widget.orgId, token: token).encode();
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (orgId: widget.orgId, propertyId: widget.property.id);
    final vacantBeds = ref.watch(vacantBedsProvider(key));

    return Scaffold(
      appBar: AppBar(title: const Text('Invite tenant')),
      body: _inviteCode != null ? _buildInviteCodeView() : _buildForm(vacantBeds),
    );
  }

  Widget _buildInviteCodeView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Invite created. Share this code with the tenant (WhatsApp/SMS) — '
            'they\'ll sign in to the app and paste it under "I have an invite code".',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
            child: SelectableText(_inviteCode!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _inviteCode!));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Bed>> vacantBeds) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncValueView<List<Bed>>(
            value: vacantBeds,
            data: (context, beds) {
              if (beds.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No vacant beds. Add a room/bed first, or free one up.'),
                );
              }
              return DropdownButtonFormField<Bed>(
                initialValue: _selectedBed,
                decoration: const InputDecoration(labelText: 'Vacant bed'),
                items: beds.map((b) => DropdownMenuItem(value: b, child: Text('Bed ${b.bedLabel}'))).toList(),
                onChanged: (b) {
                  setState(() {
                    _selectedBed = b;
                    if (b?.rentAmount != null) _rentAmount.text = b!.rentAmount!.toStringAsFixed(0);
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rentAmount,
            decoration: const InputDecoration(labelText: 'Rent amount (₹/month)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _depositAmount,
            decoration: const InputDecoration(labelText: 'Deposit amount (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expiresInDays,
            decoration: const InputDecoration(labelText: 'Invite expires in (days, max 30)'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 1 || n > 30) ? 'Must be 1-30' : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _invite,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create invite'),
          ),
        ],
      ),
    );
  }
}
