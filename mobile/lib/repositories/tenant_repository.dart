import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentle/core/network/api_client.dart';
import 'package:rentle/models/complaint_model.dart';
import 'package:rentle/models/notice_model.dart';
import 'package:rentle/models/pg_model.dart';
import 'package:rentle/models/rent_record_model.dart';
import 'package:rentle/models/room_model.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository(apiClient: ref.watch(apiClientProvider));
});

class TenantHomeData {
  const TenantHomeData({
    required this.user,
    this.pg,
    this.room,
    this.currentRent,
    this.pendingCharges = const [],
    required this.notices,
  });

  final UserModel user;
  final PgModel? pg;
  final RoomModel? room;
  final RentRecordModel? currentRent;
  final List<RentRecordModel> pendingCharges;
  final List<NoticeModel> notices;
}

class TenantRepository {
  TenantRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<TenantHomeData> getHome() async {
    final response = await _api.get<Map<String, dynamic>>('/api/tenant/home');
    final data = response.data!;
    final notices = (data['notices'] as List<dynamic>? ?? [])
        .map((e) => NoticeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pending = (data['pendingCharges'] as List<dynamic>? ?? [])
        .map((e) => RentRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return TenantHomeData(
      user: UserModel.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      ),
      pg: data['pg'] != null
          ? PgModel.fromJson(Map<String, dynamic>.from(data['pg'] as Map))
          : null,
      room: data['room'] != null
          ? RoomModel.fromJson(Map<String, dynamic>.from(data['room'] as Map))
          : null,
      currentRent: data['currentRent'] != null
          ? RentRecordModel.fromJson(
              Map<String, dynamic>.from(data['currentRent'] as Map),
            )
          : null,
      pendingCharges: pending,
      notices: notices,
    );
  }

  Future<List<RentRecordModel>> getPayments() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/tenant/payments');
    final records = response.data?['records'] as List<dynamic>? ?? [];
    return records
        .map((e) => RentRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markPaid({
    required String recordId,
    required String method,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/payments/mark-paid',
      data: {'recordId': recordId, 'method': method},
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to mark paid');
    }
  }

  Future<Map<String, dynamic>> getPaymentLink(String recordId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/tenant/payments/pay',
      data: {'recordId': recordId},
    );
    if (response.data?['success'] != true || response.data?['deepLink'] == null) {
      throw Exception(response.data?['error'] ?? 'Failed to get payment link');
    }
    return Map<String, dynamic>.from(response.data!);
  }

  Future<void> submitComplaint({
    required String type,
    required String description,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/tenant/complaints',
      data: {'type': type, 'description': description},
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to submit complaint');
    }
  }

  Future<List<ComplaintModel>> getComplaints() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/tenant/complaints');
    final complaints = response.data?['complaints'] as List<dynamic>? ?? [];
    return complaints
        .map((e) => ComplaintModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> giveNotice({required DateTime moveOutDate}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/tenant/notice',
      data: {'moveOutDate': moveOutDate.toIso8601String()},
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to submit notice');
    }
  }
}
