class RentRecordModel {
  const RentRecordModel({
    required this.recordId,
    required this.pgId,
    required this.tenantId,
    required this.roomId,
    required this.month,
    required this.year,
    required this.amount,
    this.lateFine = 0,
    this.dueDate,
    required this.status,
    this.paymentMethod,
    this.paymentDeepLink,
    this.paidAt,
    this.receiptUrl,
    this.createdAt,
    this.tenantName,
    this.roomNumber,
  });

  final String recordId;
  final String pgId;
  final String tenantId;
  final String roomId;
  final int month;
  final int year;
  final double amount;
  final double lateFine;
  final DateTime? dueDate;
  final String status;
  final String? paymentMethod;
  final String? paymentDeepLink;
  final DateTime? paidAt;
  final String? receiptUrl;
  final DateTime? createdAt;
  final String? tenantName;
  final String? roomNumber;

  factory RentRecordModel.fromJson(Map<String, dynamic> json) {
    return RentRecordModel(
      recordId: (json['recordId'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      tenantId: (json['tenantId'] ?? '') as String,
      roomId: (json['roomId'] ?? '') as String,
      month: (json['month'] ?? 1) as int,
      year: (json['year'] ?? DateTime.now().year) as int,
      amount: _toDouble(json['amount']),
      lateFine: _toDouble(json['lateFine']),
      dueDate: _parseDate(json['dueDate']),
      status: (json['status'] ?? 'unpaid') as String,
      paymentMethod: json['paymentMethod'] as String?,
      paymentDeepLink: json['paymentDeepLink'] as String?,
      paidAt: _parseDate(json['paidAt']),
      receiptUrl: json['receiptUrl'] as String?,
      createdAt: _parseDate(json['createdAt']),
      tenantName: json['tenantName'] as String?,
      roomNumber: json['roomNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'pgId': pgId,
        'tenantId': tenantId,
        'roomId': roomId,
        'month': month,
        'year': year,
        'amount': amount,
        'lateFine': lateFine,
        'status': status,
        'paymentMethod': paymentMethod,
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
