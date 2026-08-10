import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/api_providers.dart';
import '../../core/models/tenancy_models.dart';
import '../../core/models/complaint_models.dart';
import '../../core/models/document_models.dart';
import '../../core/models/discovery_models.dart';

final propertySearchProvider = FutureProvider.family<List<PropertyListing>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/property-listings/search', queryParameters: {'q': query.trim()});
  return (res.data['data'] as List).map((e) => PropertyListing.fromJson(e as Map<String, dynamic>)).toList();
});

final myJoinRequestsProvider = FutureProvider.family<List<JoinRequest>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/join-requests/mine');
  return (res.data['data'] as List).map((e) => JoinRequest.fromJson(e as Map<String, dynamic>)).toList();
});

final tenantMeProvider = FutureProvider.family<Tenancy, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/tenant/me');
  return Tenancy.fromJson(res.data['data'] as Map<String, dynamic>);
});

final tenantComplaintsProvider = FutureProvider.family<List<Complaint>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/tenant/complaints');
  return (res.data['data'] as List).map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
});

final tenantDocumentsProvider = FutureProvider.family<List<TenantDocument>, String>((ref, orgId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/$orgId/tenant/documents');
  return (res.data['data'] as List).map((e) => TenantDocument.fromJson(e as Map<String, dynamic>)).toList();
});

typedef TenantComplaintKey = ({String orgId, String complaintId});

final tenantComplaintDetailProvider = FutureProvider.family<Complaint, TenantComplaintKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/organizations/${key.orgId}/tenant/complaints/${key.complaintId}');
  return Complaint.fromJson(res.data['data'] as Map<String, dynamic>);
});
