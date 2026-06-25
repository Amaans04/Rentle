class RoomModel {
  const RoomModel({
    required this.roomId,
    required this.pgId,
    required this.roomNumber,
    this.floor,
    required this.roomType,
    required this.sharingCapacity,
    required this.currentOccupancy,
    required this.rentAmount,
    required this.mrpAmount,
    required this.status,
    this.amenities = const [],
    this.photos = const [],
    this.createdAt,
  });

  final String roomId;
  final String pgId;
  final String roomNumber;
  final int? floor;
  final String roomType;
  final int sharingCapacity;
  final int currentOccupancy;
  final double rentAmount;
  final double mrpAmount;
  final String status;
  final List<String> amenities;
  final List<String> photos;
  final DateTime? createdAt;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      roomId: (json['roomId'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      roomNumber: (json['roomNumber'] ?? '') as String,
      floor: json['floor'] as int?,
      roomType: (json['roomType'] ?? 'single') as String,
      sharingCapacity: (json['sharingCapacity'] ?? 1) as int,
      currentOccupancy: (json['currentOccupancy'] ?? 0) as int,
      rentAmount: _toDouble(json['rentAmount']),
      mrpAmount: _toDouble(json['mrpAmount']),
      status: (json['status'] ?? 'vacant') as String,
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'pgId': pgId,
        'roomNumber': roomNumber,
        'floor': floor,
        'roomType': roomType,
        'sharingCapacity': sharingCapacity,
        'currentOccupancy': currentOccupancy,
        'rentAmount': rentAmount,
        'mrpAmount': mrpAmount,
        'status': status,
        'amenities': amenities,
        'photos': photos,
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
