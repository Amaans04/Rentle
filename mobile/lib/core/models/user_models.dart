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
