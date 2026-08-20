import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/models/notice_models.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/async_value_view.dart';
import '../owner_providers.dart';

const _audiences = ['ALL_TENANTS', 'PROPERTY', 'FLOOR', 'ROOM'];

class NoticeFormSheet extends ConsumerStatefulWidget {
  const NoticeFormSheet({super.key, required this.orgId, required this.propertyId, this.existing, required this.saving});

  final String orgId;
  final String propertyId;
  final Notice? existing;
  final ValueNotifier<bool> saving;

  static Future<bool?> show(BuildContext context, {required String orgId, required String propertyId, Notice? existing}) {
    final saving = ValueNotifier(false);
    return AppBottomSheet.show<bool>(
      context,
      title: existing != null ? 'Edit notice' : 'New notice',
      saving: saving,
      builder: (_) => NoticeFormSheet(orgId: orgId, propertyId: propertyId, existing: existing, saving: saving),
    ).whenComplete(saving.dispose);
  }

  @override
  ConsumerState<NoticeFormSheet> createState() => _NoticeFormSheetState();
}

class _NoticeFormSheetState extends ConsumerState<NoticeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late String _audience = widget.existing?.audience ?? 'ALL_TENANTS';
  // Editing a FLOOR/ROOM notice starts these unset — Notice only carries
  // floorId/roomId, not the building the floor belongs to, so the
  // building→floor(→room) cascade can't be pre-filled without an extra
  // lookup. Rare edit case (retitling/rewording is the common one); the
  // owner just re-picks the target if they're changing it.
  String? _buildingId;
  String? _floorId;
  String? _roomId;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audience == 'FLOOR' && _floorId == null) {
      showErrorSnackBar(context, 'Pick a floor for a floor-targeted notice.');
      return;
    }
    if (_audience == 'ROOM' && _roomId == null) {
      showErrorSnackBar(context, 'Pick a room for a room-targeted notice.');
      return;
    }
    widget.saving.value = true;
    try {
      final api = ref.read(apiClientProvider);
      final data = {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'audience': _audience,
        if (_audience == 'FLOOR') 'floorId': _floorId,
        if (_audience == 'ROOM') 'roomId': _roomId,
      };
      if (_isEditing) {
        await api.dio.patch('/organizations/${widget.orgId}/notices/${widget.existing!.id}', data: data);
      } else {
        await api.dio.post('/organizations/${widget.orgId}/properties/${widget.propertyId}/notices', data: data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      widget.saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _body,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _audience,
            decoration: const InputDecoration(labelText: 'Visible to'),
            items: _audiences.map((a) => DropdownMenuItem(value: a, child: Text(_audienceLabel(a)))).toList(),
            onChanged: (v) => setState(() {
              _audience = v!;
              _buildingId = null;
              _floorId = null;
              _roomId = null;
            }),
          ),
          if (_audience == 'FLOOR' || _audience == 'ROOM') ...[const SizedBox(height: 12), _buildingPicker()],
          if (_buildingId != null && (_audience == 'FLOOR' || _audience == 'ROOM')) ...[
            const SizedBox(height: 12),
            _floorPicker(),
          ],
          if (_floorId != null && _audience == 'ROOM') ...[const SizedBox(height: 12), _roomPicker()],
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: widget.saving,
            builder: (context, saving, _) => FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save changes' : 'Publish notice'),
            ),
          ),
        ],
      ),
    );
  }

  String _audienceLabel(String a) => switch (a) {
    'ALL_TENANTS' => 'Every tenant',
    'PROPERTY' => 'This property',
    'FLOOR' => 'One floor',
    'ROOM' => 'One room',
    _ => titleCase(a),
  };

  Widget _buildingPicker() {
    final buildings = ref.watch(buildingsProvider((orgId: widget.orgId, propertyId: widget.propertyId)));
    return AsyncValueView<List<Building>>(
      value: buildings,
      data: (context, list) => DropdownButtonFormField<String>(
        initialValue: _buildingId,
        decoration: const InputDecoration(labelText: 'Building'),
        items: list.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
        onChanged: (v) => setState(() {
          _buildingId = v;
          _floorId = null;
          _roomId = null;
        }),
      ),
    );
  }

  Widget _floorPicker() {
    final floors = ref.watch(floorsProvider((orgId: widget.orgId, buildingId: _buildingId!)));
    return AsyncValueView<List<Floor>>(
      value: floors,
      data: (context, list) => DropdownButtonFormField<String>(
        initialValue: _floorId,
        decoration: const InputDecoration(labelText: 'Floor'),
        items: list.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
        onChanged: (v) => setState(() {
          _floorId = v;
          _roomId = null;
        }),
      ),
    );
  }

  Widget _roomPicker() {
    final rooms = ref.watch(
      roomsForFloorProvider((orgId: widget.orgId, propertyId: widget.propertyId, floorId: _floorId!)),
    );
    return AsyncValueView<List<Room>>(
      value: rooms,
      data: (context, list) => DropdownButtonFormField<String>(
        initialValue: _roomId,
        decoration: const InputDecoration(labelText: 'Room'),
        items: list.map((r) => DropdownMenuItem(value: r.id, child: Text('Room ${r.roomNumber}'))).toList(),
        onChanged: (v) => setState(() => _roomId = v),
      ),
    );
  }
}
