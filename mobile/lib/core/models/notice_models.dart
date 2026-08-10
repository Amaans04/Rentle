import 'parsing.dart';

/// Mirrors server's NoticeAudience enum: ALL_TENANTS/PROPERTY/FLOOR/ROOM/CUSTOM.
class Notice {
  Notice({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    this.floorId,
    this.roomId,
    this.publishAt,
    this.expiresAt,
    this.publishedAt,
  });

  final String id;
  final String propertyId;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;
  final String? floorId;
  final String? roomId;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final DateTime? publishedAt;

  bool get isPublished => publishedAt != null;

  factory Notice.fromJson(Map<String, dynamic> json) {
    final filter = json['audienceFilter'] as Map<String, dynamic>?;
    return Notice(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      audience: json['audience'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      floorId: filter?['floorId'] as String?,
      roomId: filter?['roomId'] as String?,
      publishAt: parseDateOrNull(json['publishAt']),
      expiresAt: parseDateOrNull(json['expiresAt']),
      publishedAt: parseDateOrNull(json['publishedAt']),
    );
  }
}
