class TenantModel {
  const TenantModel({
    required this.uid,
    required this.pgId,
    required this.roomId,
    required this.moveInDate,
    required this.rentAmount,
    required this.depositAmount,
    required this.status,
    this.noticeDate,
    this.moveOutDate,
    required this.addedBy,
    this.name,
    this.phone,
    this.photoURL,
    this.roomNumber,
    this.rentStatus,
  });

  final String uid;
  final String pgId;
  final String roomId;
  final DateTime? moveInDate;
  final double rentAmount;
  final double depositAmount;
  final String status;
  final DateTime? noticeDate;
  final DateTime? moveOutDate;
  final String addedBy;
  final String? name;
  final String? phone;
  final String? photoURL;
  final String? roomNumber;
  final String? rentStatus;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      roomId: (json['roomId'] ?? '') as String,
      moveInDate: _parseDate(json['moveInDate']),
      rentAmount: _toDouble(json['rentAmount']),
      depositAmount: _toDouble(json['depositAmount']),
      status: (json['status'] ?? 'active') as String,
      noticeDate: _parseDate(json['noticeDate']),
      moveOutDate: _parseDate(json['moveOutDate']),
      addedBy: (json['addedBy'] ?? '') as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      photoURL: json['photoURL'] as String?,
      roomNumber: json['roomNumber'] as String?,
      rentStatus: json['rentStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'pgId': pgId,
        'roomId': roomId,
        'moveInDate': moveInDate?.toIso8601String(),
        'rentAmount': rentAmount,
        'depositAmount': depositAmount,
        'status': status,
        'noticeDate': noticeDate?.toIso8601String(),
        'moveOutDate': moveOutDate?.toIso8601String(),
        'addedBy': addedBy,
      };

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as int) * 1000,
      );
    }
    return null;
  }
}

class StaffModel {
  const StaffModel({
    required this.uid,
    required this.pgId,
    required this.role,
    required this.name,
    required this.phone,
    required this.addedBy,
    this.active = true,
    this.createdAt,
  });

  final String uid;
  final String pgId;
  final String role;
  final String name;
  final String phone;
  final String addedBy;
  final bool active;
  final DateTime? createdAt;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as int) * 1000,
      );
    }
    return null;
  }

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      role: (json['role'] ?? 'manager') as String,
      name: (json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      addedBy: (json['addedBy'] ?? '') as String,
      active: json['active'] != false,
      createdAt: _parseDate(json['createdAt']),
    );
  }
}
