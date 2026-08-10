/// Mirrors server's ComplaintStatus enum: OPEN/IN_PROGRESS/ESCALATED/RESOLVED/CLOSED/REOPENED.
class Complaint {
  Complaint({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.reporterName,
    this.assigneeId,
    this.assigneeName,
    this.comments = const [],
  });

  final String id;
  final String propertyId;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final String? reporterName;
  final String? assigneeId;
  final String? assigneeName;
  final List<ComplaintComment> comments;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>?;
    final assignee = json['assignee'] as Map<String, dynamic>?;
    return Complaint(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reporterName: reporter?['name'] as String? ?? reporter?['phone'] as String?,
      assigneeId: json['assigneeId'] as String?,
      assigneeName: assignee?['name'] as String?,
      comments: (json['comments'] as List?)?.map((e) => ComplaintComment.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}

class ComplaintComment {
  ComplaintComment({required this.id, required this.content, required this.authorId, required this.createdAt});

  final String id;
  final String content;
  final String authorId;
  final DateTime createdAt;

  factory ComplaintComment.fromJson(Map<String, dynamic> json) => ComplaintComment(
    id: json['id'] as String,
    content: json['content'] as String,
    authorId: json['authorId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
