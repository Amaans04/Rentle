import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/api_providers.dart';
import '../../core/models/property_models.dart';
import '../../core/models/tenancy_models.dart';
import '../../core/models/invoice_models.dart';
import '../../core/models/complaint_models.dart';
import '../../core/models/document_models.dart';
import '../../core/models/user_models.dart';
import '../../core/models/discovery_models.dart';
import '../../core/models/notice_models.dart';

typedef PropertyKey = ({String orgId, String propertyId});
typedef BuildingKey = ({String orgId, String buildingId});
typedef FloorRoomsKey = ({String orgId, String propertyId, String floorId});
typedef TenanciesKey = ({String orgId, String propertyId, String? status});
typedef InvoicesKey = ({String orgId, String propertyId, String? status});
typedef ComplaintsKey = ({String orgId, String propertyId, String? status, String? priority});
typedef BedsKey = ({String orgId, String propertyId, String? status});

final propertiesProvider = FutureProvider.family<List<Property>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/properties');
  return (res.data['data'] as List).map((e) => Property.fromJson(e as Map<String, dynamic>)).toList();
});

final buildingsProvider = FutureProvider.family<List<Building>, PropertyKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/properties/${key.propertyId}/buildings');
  return (res.data['data'] as List).map((e) => Building.fromJson(e as Map<String, dynamic>)).toList();
});

final floorsProvider = FutureProvider.family<List<Floor>, BuildingKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/buildings/${key.buildingId}/floors');
  return (res.data['data'] as List).map((e) => Floor.fromJson(e as Map<String, dynamic>)).toList();
});

final roomsForFloorProvider = FutureProvider.family<List<Room>, FloorRoomsKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/properties/${key.propertyId}/rooms',
    queryParameters: {'floorId': key.floorId},
  );
  return (res.data['data'] as List).map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
});

final vacantBedsProvider = FutureProvider.family<List<Bed>, PropertyKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/properties/${key.propertyId}/beds',
    queryParameters: {'status': 'VACANT'},
  );
  return (res.data['data'] as List).map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList();
});

final tenanciesProvider = FutureProvider.family<List<Tenancy>, TenanciesKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/properties/${key.propertyId}/tenancies',
    queryParameters: key.status != null ? {'status': key.status} : null,
  );
  return (res.data['data'] as List).map((e) => Tenancy.fromJson(e as Map<String, dynamic>)).toList();
});

final invoicesProvider = FutureProvider.family<List<Invoice>, InvoicesKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/properties/${key.propertyId}/invoices',
    queryParameters: key.status != null ? {'status': key.status} : null,
  );
  return (res.data['data'] as List).map((e) => Invoice.fromJson(e as Map<String, dynamic>)).toList();
});

final complaintsProvider = FutureProvider.family<List<Complaint>, ComplaintsKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/properties/${key.propertyId}/complaints',
    queryParameters: {if (key.status != null) 'status': key.status!, if (key.priority != null) 'priority': key.priority!},
  );
  return (res.data['data'] as List).map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
});

typedef InvoiceDetailKey = ({String orgId, String invoiceId});

final invoiceDetailProvider = FutureProvider.family<InvoiceDetail, InvoiceDetailKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/invoices/${key.invoiceId}');
  return InvoiceDetail.fromJson(res.data['data'] as Map<String, dynamic>);
});

typedef ComplaintDetailKey = ({String orgId, String complaintId});

final complaintDetailProvider = FutureProvider.family<Complaint, ComplaintDetailKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/complaints/${key.complaintId}');
  return Complaint.fromJson(res.data['data'] as Map<String, dynamic>);
});

typedef TenancyKey = ({String orgId, String tenancyId});

final tenancyDocumentsProvider = FutureProvider.family<List<TenantDocument>, TenancyKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/tenancies/${key.tenancyId}/documents');
  return (res.data['data'] as List).map((e) => TenantDocument.fromJson(e as Map<String, dynamic>)).toList();
});

final orgMembersProvider = FutureProvider.family<List<OrgMemberSummary>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/members');
  return (res.data['data'] as List).map((e) => OrgMemberSummary.fromJson(e as Map<String, dynamic>)).toList();
});

typedef JoinRequestsKey = ({String orgId, String? status});

final joinRequestsProvider = FutureProvider.family<List<JoinRequest>, JoinRequestsKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get(
    '/organizations/${key.orgId}/join-requests',
    queryParameters: key.status != null ? {'status': key.status} : null,
  );
  return (res.data['data'] as List).map((e) => JoinRequest.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Staff management ---

final fullOrgMembersProvider = FutureProvider.family<List<OrgMember>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/members');
  return (res.data['data'] as List).map((e) => OrgMember.fromJson(e as Map<String, dynamic>)).toList();
});

typedef StaffProfileKey = ({String orgId, String memberId});

final staffProfileProvider = FutureProvider.family<StaffProfile?, StaffProfileKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.dio.get('/organizations/${key.orgId}/members/${key.memberId}/staff-profile');
    return StaffProfile.fromJson(res.data['data'] as Map<String, dynamic>);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null; // no profile set yet — not an error
    rethrow;
  }
});

// --- Notices ---

final noticesProvider = FutureProvider.family<List<Notice>, PropertyKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/properties/${key.propertyId}/notices');
  return (res.data['data'] as List).map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
});
