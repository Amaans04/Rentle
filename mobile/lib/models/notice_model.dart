class NoticeModel {
  const NoticeModel({
    required this.noticeId,
    required this.pgId,
    required this.title,
    required this.body,
    required this.createdBy,
    this.createdAt,
    required this.targetRole,
    this.creatorName,
  });

  final String noticeId;
  final String pgId;
  final String title;
  final String body;
  final String createdBy;
  final DateTime? createdAt;
  final String targetRole;
  final String? creatorName;

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      noticeId: (json['noticeId'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdBy: (json['createdBy'] ?? '') as String,
      createdAt: _parseDate(json['createdAt']),
      targetRole: (json['targetRole'] ?? 'all') as String,
      creatorName: json['creatorName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'noticeId': noticeId,
        'pgId': pgId,
        'title': title,
        'body': body,
        'createdBy': createdBy,
        'targetRole': targetRole,
      };

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
