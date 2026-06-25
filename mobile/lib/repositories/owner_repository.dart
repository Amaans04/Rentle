import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentle/core/network/api_client.dart';
import 'package:rentle/models/complaint_model.dart';
import 'package:rentle/models/notice_model.dart';
import 'package:rentle/models/rent_record_model.dart';
import 'package:rentle/models/room_model.dart';
import 'package:rentle/models/tenant_model.dart';
import 'package:rentle/models/user_model.dart';
import 'package:rentle/repositories/auth_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository(apiClient: ref.watch(apiClientProvider));
});

class OwnerDashboardData {
  const OwnerDashboardData({
    required this.pg,
    required this.summary,
    required this.activities,
  });

  final Map<String, dynamic> pg;
  final Map<String, int> summary;
  final List<Map<String, dynamic>> activities;
}

class OwnerRepository {
  OwnerRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<Map<String, dynamic>> setupProperty({
    required String name,
    required String propertyName,
    required String address,
    required String city,
    required int roomCount,
    required String genderType,
    required int rentDueDate,
    required String contactPhone,
    String? upiId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/owner/setup',
      data: {
        'name': name,
        'propertyName': propertyName,
        'address': address,
        'city': city,
        'roomCount': roomCount,
        'genderType': genderType,
        'rentDueDate': rentDueDate,
        'contactPhone': contactPhone,
        if (upiId != null) 'upiId': upiId,
      },
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Setup failed');
    }
    return response.data!;
  }

  Future<OwnerDashboardData> getDashboard() async {
    final response = await _api.get<Map<String, dynamic>>('/api/owner/dashboard');
    final data = response.data!;
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final activities = (data['activities'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return OwnerDashboardData(
      pg: Map<String, dynamic>.from(data['pg'] as Map? ?? {}),
      summary: {
        'totalRooms': (summary['totalRooms'] ?? 0) as int,
        'occupied': (summary['occupied'] ?? 0) as int,
        'vacant': (summary['vacant'] ?? 0) as int,
        'rentCollected': (summary['rentCollected'] ?? 0) as int,
      },
      activities: activities,
    );
  }

  Future<List<RoomModel>> getRooms() async {
    final response = await _api.get<Map<String, dynamic>>('/api/owner/rooms');
    final rooms = response.data?['rooms'] as List<dynamic>? ?? [];
    return rooms
        .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RoomModel> createRoom(Map<String, dynamic> data) async {
    final response =
        await _api.post<Map<String, dynamic>>('/api/owner/rooms', data: data);
    final room = response.data?['room'];
    if (room is Map) {
      return RoomModel.fromJson(Map<String, dynamic>.from(room));
    }
    if (response.data?['success'] == true) {
      final rooms = await getRooms();
      final roomId = response.data?['roomId'] as String?;
      return rooms.firstWhere(
        (r) => r.roomId == roomId,
        orElse: () => rooms.last,
      );
    }
    throw Exception(response.data?['error'] ?? 'Failed to create room');
  }

  Future<RoomModel> updateRoom(String roomId, Map<String, dynamic> data) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/owner/rooms/$roomId',
      data: data,
    );
    final room = response.data?['room'];
    if (room is Map) {
      return RoomModel.fromJson(Map<String, dynamic>.from(room));
    }
    if (response.data?['success'] == true) {
      final rooms = await getRooms();
      return rooms.firstWhere((r) => r.roomId == roomId);
    }
    throw Exception(response.data?['error'] ?? 'Failed to update room');
  }

  Future<void> deleteRoom(String roomId) async {
    final response = await _api.delete<Map<String, dynamic>>(
      '/api/owner/rooms/$roomId',
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to delete room');
    }
  }

  Future<List<TenantModel>> getTenants() async {
    final response = await _api.get<Map<String, dynamic>>('/api/owner/tenants');
    final tenants = response.data?['tenants'] as List<dynamic>? ?? [];
    return tenants
        .map((e) => TenantModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<UserModel?> searchTenantByPhone(String phone) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/owner/tenants/search',
      queryParameters: {'phone': phone},
    );
    if (response.data?['found'] != true || response.data?['user'] == null) {
      return null;
    }
    return UserModel.fromJson(
      Map<String, dynamic>.from(response.data!['user'] as Map),
    );
  }

  Future<String> inviteTenant({
    required String name,
    required String phone,
    required String roomId,
    required DateTime moveInDate,
    required double rentAmount,
    required double depositAmount,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/owner/tenants/invite',
      data: {
        'name': name,
        'phone': phone,
        'roomId': roomId,
        'moveInDate': moveInDate.toIso8601String(),
        'rentAmount': rentAmount,
        'depositAmount': depositAmount,
      },
    );
    return response.data?['inviteId'] as String? ?? '';
  }

  Future<List<StaffModel>> getStaff() async {
    final response = await _api.get<Map<String, dynamic>>('/api/owner/staff');
    final staff = response.data?['staff'] as List<dynamic>? ?? [];
    return staff
        .map((e) => StaffModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> inviteStaff({required String phone}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/owner/staff/invite',
      data: {'phone': phone},
    );
    return response.data?['inviteId'] as String? ?? '';
  }

  Future<List<ComplaintModel>> getComplaints() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/owner/complaints');
    final complaints = response.data?['complaints'] as List<dynamic>? ?? [];
    return complaints
        .map((e) => ComplaintModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ComplaintModel> updateComplaint(
    String id, {
    String? status,
    String? assignedTo,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/owner/complaints/$id',
      data: {
        if (status != null) 'status': status,
        if (assignedTo != null) 'assignedTo': assignedTo,
      },
    );
    return ComplaintModel.fromJson(
      Map<String, dynamic>.from(response.data!['complaint'] as Map),
    );
  }

  Future<List<NoticeModel>> getNotices() async {
    final response = await _api.get<Map<String, dynamic>>('/api/owner/notices');
    final notices = response.data?['notices'] as List<dynamic>? ?? [];
    return notices
        .map((e) => NoticeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<NoticeModel> createNotice({
    required String title,
    required String body,
    required String targetRole,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/owner/notices',
      data: {'title': title, 'body': body, 'targetRole': targetRole},
    );
    return NoticeModel.fromJson(
      Map<String, dynamic>.from(response.data!['notice'] as Map),
    );
  }

  Future<List<RentRecordModel>> getRentRecords({
    int? month,
    int? year,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/owner/rent-records',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    final records = response.data?['records'] as List<dynamic>? ?? [];
    return records
        .map((e) => RentRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> generateRentRecords() async {
    await _api.post('/api/owner/rent-records/generate');
  }

  Future<void> createCharge({
    required String tenantId,
    required String chargeType,
    required String description,
    required double amount,
    DateTime? dueDate,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/owner/charges',
      data: {
        'tenantId': tenantId,
        'chargeType': chargeType,
        'description': description,
        'amount': amount,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      },
    );
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to create charge');
    }
  }
}
