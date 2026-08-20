import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/property_models.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../owner_providers.dart';
import '../rooms_beds/buildings_screen.dart';
import '../rooms_beds/building_form_sheet.dart';
import '../tenants/tenants_list_screen.dart';
import '../tenants/tenant_invite_screen.dart';
import '../tenants/join_requests_screen.dart';
import '../invoices/invoices_list_screen.dart';
import '../invoices/generate_invoices_sheet.dart';
import '../complaints/complaints_list_screen.dart';
import '../notices/notice_form_sheet.dart';
import '../notices/notices_list_screen.dart';
import 'property_form_screen.dart';

/// Everything for one property lives here as tabs — matches how an owner
/// actually thinks about the work ("set up my property"), and every
/// resource under it (rooms/beds, tenants, invoices, complaints) is scoped
/// by propertyId in the API anyway.
class PropertyWorkspaceScreen extends ConsumerStatefulWidget {
  const PropertyWorkspaceScreen({super.key, required this.orgId, required this.property});

  final String orgId;
  final Property property;

  @override
  ConsumerState<PropertyWorkspaceScreen> createState() => _PropertyWorkspaceScreenState();
}

class _PropertyWorkspaceScreenState extends ConsumerState<PropertyWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Property _property = widget.property;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PropertyKey get _key => (orgId: widget.orgId, propertyId: _property.id);

  Future<void> _editProperty() async {
    final edited = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => PropertyFormScreen(orgId: widget.orgId, existing: _property)));
    if (edited == true) {
      setState(() => _busy = true);
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.dio.get('/organizations/${widget.orgId}/properties/${_property.id}');
        setState(() => _property = Property.fromJson(res.data['data'] as Map<String, dynamic>));
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProperty() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this property?',
      message: '"${_property.name}" and everything under it stays in records but is removed from view. This cannot be undone from the app.',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/organizations/${widget.orgId}/properties/${_property.id}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFabPressed() async {
    switch (_tabController.index) {
      case 0:
        final created = await BuildingFormSheet.show(context, orgId: widget.orgId, propertyId: _property.id);
        if (created == true) ref.invalidate(buildingsProvider(_key));
        break;
      case 1:
        final invited = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => TenantInviteScreen(orgId: widget.orgId, property: _property)),
        );
        if (invited == true) {
          ref.invalidate(tenanciesProvider((orgId: widget.orgId, propertyId: _property.id, status: null)));
        }
        break;
      case 2:
        final generated = await GenerateInvoicesSheet.show(context, orgId: widget.orgId, propertyId: _property.id);
        if (generated == true) {
          ref.invalidate(invoicesProvider((orgId: widget.orgId, propertyId: _property.id, status: null)));
        }
        break;
      case 5:
        final posted = await NoticeFormSheet.show(context, orgId: widget.orgId, propertyId: _property.id);
        if (posted == true) ref.invalidate(noticesProvider(_key));
        break;
    }
  }

  // Sparse — Complaints (3) and Requests (4) have no FAB action, matching
  // how those tabs already work (complaints only come from tenants;
  // requests are approved/rejected inline, not "created" by the owner).
  static const _fabByTab = {
    0: (icon: Icons.add_business, label: 'Add building'),
    1: (icon: Icons.person_add, label: 'Invite tenant'),
    2: (icon: Icons.receipt_long, label: 'Generate invoices'),
    5: (icon: Icons.campaign, label: 'New notice'),
  };

  @override
  Widget build(BuildContext context) {
    final fab = _fabByTab[_tabController.index];

    return Scaffold(
      appBar: AppBar(
        title: Text(_property.name),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? _editProperty() : _deleteProperty(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit property')),
                PopupMenuItem(value: 'delete', child: Text('Delete property')),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: const EdgeInsets.symmetric(vertical: 8),
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: const [
            Tab(text: 'Rooms & Beds'),
            Tab(text: 'Tenants'),
            Tab(text: 'Invoices'),
            Tab(text: 'Complaints'),
            Tab(text: 'Requests'),
            Tab(text: 'Notices'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BuildingsScreen(orgId: widget.orgId, property: _property),
          TenantsListScreen(orgId: widget.orgId, property: _property),
          InvoicesListScreen(orgId: widget.orgId, property: _property),
          ComplaintsListScreen(orgId: widget.orgId, property: _property),
          JoinRequestsScreen(orgId: widget.orgId, property: _property),
          NoticesListScreen(orgId: widget.orgId, property: _property),
        ],
      ),
      // The FAB's action genuinely changes meaning with the tab (add
      // building vs invite tenant vs generate invoices) — a scale+fade swap
      // is the standard Material pattern for that, and it's seen every time
      // an owner switches tabs, so it earns a real transition rather than
      // an abrupt icon/label swap.
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
        child: fab != null
            ? FloatingActionButton.extended(
                key: ValueKey(_tabController.index),
                onPressed: _onFabPressed,
                icon: Icon(fab.icon),
                label: Text(fab.label),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }
}
