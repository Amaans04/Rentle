class AppUser {
  AppUser({required this.id, this.email, this.phone, this.name});

  final String id;
  final String? email;
  final String? phone;
  final String? name;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    name: json['name'] as String?,
  );

  String get displayName => name?.isNotEmpty == true ? name! : (email ?? phone ?? id);
}

/// `role` mirrors server's OrgMemberRole enum: OWNER/MANAGER/RECEPTIONIST/ACCOUNTANT/STAFF.
class Membership {
  Membership({
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.propertyIds,
  });

  final String organizationId;
  final String organizationName;
  final String role;
  final List<String> propertyIds;

  bool get isUnrestricted => propertyIds.isEmpty;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    organizationId: json['organizationId'] as String,
    organizationName: json['organizationName'] as String? ?? '',
    role: json['role'] as String,
    propertyIds: (json['propertyIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// A member of an org (for the complaint-assignment dropdown, etc).
/// `userId` is what assignment endpoints expect, NOT the membership id.
class OrgMemberSummary {
  OrgMemberSummary({required this.userId, required this.name, required this.role});

  final String userId;
  final String name;
  final String role;

  factory OrgMemberSummary.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return OrgMemberSummary(
      userId: json['userId'] as String,
      name: (user?['name'] as String?)?.isNotEmpty == true ? user!['name'] as String : (user?['email'] as String? ?? 'Unnamed'),
      role: json['role'] as String,
    );
  }
}

/// Full membership row for the staff-management screens — unlike
/// [OrgMemberSummary] (a narrow projection for the complaint-assignee
/// dropdown), this carries everything GET /organizations/:orgId/members
/// actually returns, including `id` (the membership id PATCH/DELETE
/// /members/:memberId expect, NOT userId).
class OrgMember {
  OrgMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.propertyIds,
    required this.isActive,
    this.userName,
    this.userEmail,
    this.userPhone,
  });

  final String id;
  final String userId;
  final String role;
  final List<String> propertyIds;
  final bool isActive;
  final String? userName;
  final String? userEmail;
  final String? userPhone;

  bool get isUnrestricted => propertyIds.isEmpty;
  String get displayName => userName?.isNotEmpty == true ? userName! : (userEmail ?? userPhone ?? 'Unnamed');

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return OrgMember(
      id: json['id'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      propertyIds: (json['propertyIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: json['isActive'] as bool? ?? true,
      userName: user?['name'] as String?,
      userEmail: user?['email'] as String?,
      userPhone: user?['phone'] as String?,
    );
  }
}

class StaffProfile {
  StaffProfile({this.salary, this.joinDate});

  final double? salary;
  final DateTime? joinDate;

  factory StaffProfile.fromJson(Map<String, dynamic> json) => StaffProfile(
    salary: json['salary'] == null ? null : double.tryParse(json['salary'].toString()),
    joinDate: json['joinDate'] == null ? null : DateTime.tryParse(json['joinDate'] as String),
  );
}
