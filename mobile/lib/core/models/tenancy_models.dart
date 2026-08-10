import 'parsing.dart';

/// Mirrors server's TenancyStatus enum: PENDING_ONBOARDING/ACTIVE/NOTICE_GIVEN/ARCHIVED.
class Tenancy {
  Tenancy({
    required this.id,
    required this.organizationId,
    required this.propertyId,
    required this.bedId,
    required this.userId,
    required this.status,
    required this.rentAmount,
    required this.depositAmount,
    this.moveInDate,
    this.noticeDate,
    this.moveOutDate,
    this.tenantName,
    this.tenantEmail,
    this.tenantPhone,
    this.bedLabel,
    this.events = const [],
  });

  final String id;
  final String organizationId;
  final String propertyId;
  final String bedId;
  final String userId;
  final String status;
  final double rentAmount;
  final double depositAmount;
  final DateTime? moveInDate;
  final DateTime? noticeDate;
  final DateTime? moveOutDate;
  final String? tenantName;
  final String? tenantEmail;
  final String? tenantPhone;
  final String? bedLabel;
  final List<TenancyEvent> events;

  factory Tenancy.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final bed = json['bed'] as Map<String, dynamic>?;
    return Tenancy(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      propertyId: json['propertyId'] as String,
      bedId: json['bedId'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      rentAmount: parseNum(json['rentAmount']),
      depositAmount: parseNum(json['depositAmount']),
      moveInDate: parseDateOrNull(json['moveInDate']),
      noticeDate: parseDateOrNull(json['noticeDate']),
      moveOutDate: parseDateOrNull(json['moveOutDate']),
      tenantName: user?['name'] as String?,
      tenantEmail: user?['email'] as String?,
      tenantPhone: user?['phone'] as String?,
      bedLabel: bed?['bedLabel'] as String?,
      events: (json['events'] as List?)?.map((e) => TenancyEvent.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }

  String get displayName => tenantName?.isNotEmpty == true ? tenantName! : (tenantEmail ?? tenantPhone ?? 'Tenant');
}

class TenancyEvent {
  TenancyEvent({required this.type, required this.createdAt});

  final String type;
  final DateTime createdAt;

  factory TenancyEvent.fromJson(Map<String, dynamic> json) =>
      TenancyEvent(type: json['type'] as String, createdAt: DateTime.parse(json['createdAt'] as String));
}
