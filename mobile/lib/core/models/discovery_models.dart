/// A public, cross-org search result — only ever name/city/state, mirroring
/// the server's deliberately narrow PropertyListing (see its model comment
/// in schema.prisma). Never carries anything the RLS-protected Property
/// table itself holds.
class PropertyListing {
  PropertyListing({required this.organizationId, required this.propertyId, required this.name, required this.city, required this.state});

  final String organizationId;
  final String propertyId;
  final String name;
  final String city;
  final String state;

  factory PropertyListing.fromJson(Map<String, dynamic> json) => PropertyListing(
    organizationId: json['organizationId'] as String,
    propertyId: json['propertyId'] as String,
    name: json['name'] as String,
    city: json['city'] as String,
    state: json['state'] as String,
  );
}

/// Mirrors server's JoinRequestStatus enum: PENDING/APPROVED/REJECTED/CANCELLED.
class JoinRequest {
  JoinRequest({
    required this.id,
    required this.organizationId,
    required this.propertyId,
    required this.status,
    required this.createdAt,
    this.propertyName,
    this.message,
    this.tenancyId,
    this.responseNote,
    this.requesterName,
    this.requesterEmail,
    this.requesterPhone,
  });

  final String id;
  final String organizationId;
  final String propertyId;
  final String status;
  final DateTime createdAt;
  final String? propertyName;
  final String? message;
  final String? tenancyId;
  final String? responseNote;
  final String? requesterName;
  final String? requesterEmail;
  final String? requesterPhone;

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return JoinRequest(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      propertyId: json['propertyId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      propertyName: property?['name'] as String?,
      message: json['message'] as String?,
      tenancyId: json['tenancyId'] as String?,
      responseNote: json['responseNote'] as String?,
      requesterName: user?['name'] as String?,
      requesterEmail: user?['email'] as String?,
      requesterPhone: user?['phone'] as String?,
    );
  }

  String get requesterDisplayName =>
      requesterName?.isNotEmpty == true ? requesterName! : (requesterEmail ?? requesterPhone ?? 'Prospective tenant');
}
