class PgModel {
  const PgModel({
    required this.pgId,
    required this.name,
    required this.address,
    required this.city,
    required this.ownerId,
    required this.roomCount,
    required this.rentDueDate,
    this.active = true,
    this.amenities = const [],
    required this.contactPhone,
    required this.genderType,
    this.upiId,
    this.createdAt,
    this.updatedAt,
  });

  final String pgId;
  final String name;
  final String address;
  final String city;
  final String ownerId;
  final int roomCount;
  final int rentDueDate;
  final bool active;
  final List<String> amenities;
  final String contactPhone;
  final String genderType;
  final String? upiId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PgModel.fromJson(Map<String, dynamic> json) {
    return PgModel(
      pgId: (json['pgId'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      ownerId: (json['ownerId'] ?? '') as String,
      roomCount: (json['roomCount'] ?? 0) as int,
      rentDueDate: (json['rentDueDate'] ?? 1) as int,
      active: json['active'] != false,
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      contactPhone: (json['contactPhone'] ?? '') as String,
      genderType: (json['genderType'] ?? 'unisex') as String,
      upiId: json['upiId'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'pgId': pgId,
        'name': name,
        'address': address,
        'city': city,
        'ownerId': ownerId,
        'roomCount': roomCount,
        'rentDueDate': rentDueDate,
        'active': active,
        'amenities': amenities,
        'contactPhone': contactPhone,
        'genderType': genderType,
        'upiId': upiId,
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
