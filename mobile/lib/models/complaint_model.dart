class ComplaintModel {
  const ComplaintModel({
    required this.complaintId,
    required this.pgId,
    required this.tenantId,
    required this.roomId,
    required this.type,
    required this.description,
    required this.status,
    this.assignedTo,
    this.createdAt,
    this.resolvedAt,
    this.tenantName,
    this.roomNumber,
  });

  final String complaintId;
  final String pgId;
  final String tenantId;
  final String roomId;
  final String type;
  final String description;
  final String status;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? tenantName;
  final String? roomNumber;

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      complaintId: (json['complaintId'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      tenantId: (json['tenantId'] ?? '') as String,
      roomId: (json['roomId'] ?? '') as String,
      type: (json['type'] ?? 'other') as String,
      description: (json['description'] ?? '') as String,
      status: (json['status'] ?? 'open') as String,
      assignedTo: json['assignedTo'] as String?,
      createdAt: _parseDate(json['createdAt']),
      resolvedAt: _parseDate(json['resolvedAt']),
      tenantName: json['tenantName'] as String?,
      roomNumber: json['roomNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'complaintId': complaintId,
        'pgId': pgId,
        'tenantId': tenantId,
        'roomId': roomId,
        'type': type,
        'description': description,
        'status': status,
        'assignedTo': assignedTo,
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
