import 'parsing.dart';

class TenantDocument {
  TenantDocument({
    required this.id,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  factory TenantDocument.fromJson(Map<String, dynamic> json) => TenantDocument(
    id: json['id'] as String,
    type: json['type'] as String,
    fileName: json['fileName'] as String,
    mimeType: json['mimeType'] as String,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    createdAt: parseDateOrNull(json['createdAt']) ?? DateTime.now(),
  );
}
