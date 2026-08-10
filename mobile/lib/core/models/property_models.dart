import 'parsing.dart';

class Address {
  Address({required this.line1, this.line2, required this.city, required this.state, required this.pincode});

  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    line1: json['line1'] as String? ?? '',
    line2: json['line2'] as String?,
    city: json['city'] as String? ?? '',
    state: json['state'] as String? ?? '',
    pincode: json['pincode'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'line1': line1,
    if (line2 != null && line2!.isNotEmpty) 'line2': line2,
    'city': city,
    'state': state,
    'pincode': pincode,
  };

  String get oneLine => [line1, if (line2 != null && line2!.isNotEmpty) line2, city, state, pincode].join(', ');
}

class Property {
  Property({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.slug,
    required this.type,
    required this.address,
    this.phone,
    this.email,
    required this.amenities,
    required this.rentDueDay,
    required this.gracePeriodDays,
  });

  final String id;
  final String organizationId;
  final String name;
  final String slug;
  final String type;
  final Address address;
  final String? phone;
  final String? email;
  final List<String> amenities;
  final int rentDueDay;
  final int gracePeriodDays;

  factory Property.fromJson(Map<String, dynamic> json) => Property(
    id: json['id'] as String,
    organizationId: json['organizationId'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    type: json['type'] as String? ?? 'PG',
    address: Address.fromJson((json['address'] as Map?)?.cast<String, dynamic>() ?? const {}),
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    amenities: (json['amenities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    rentDueDay: json['rentDueDay'] as int? ?? 5,
    gracePeriodDays: json['gracePeriodDays'] as int? ?? 3,
  );
}

class Building {
  Building({required this.id, required this.propertyId, required this.name, required this.sortOrder});

  final String id;
  final String propertyId;
  final String name;
  final int sortOrder;

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['id'] as String,
    propertyId: json['propertyId'] as String,
    name: json['name'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}

class Floor {
  Floor({required this.id, required this.buildingId, required this.name, required this.level});

  final String id;
  final String buildingId;
  final String name;
  final int level;

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
    id: json['id'] as String,
    buildingId: json['buildingId'] as String,
    name: json['name'] as String,
    level: json['level'] as int? ?? 0,
  );
}

class Room {
  Room({
    required this.id,
    required this.propertyId,
    required this.floorId,
    required this.roomNumber,
    required this.roomType,
    required this.sharingCapacity,
    required this.rentAmount,
    required this.mrpAmount,
    required this.beds,
  });

  final String id;
  final String propertyId;
  final String floorId;
  final String roomNumber;
  final String roomType;
  final int sharingCapacity;
  final double rentAmount;
  final double mrpAmount;
  final List<Bed> beds;

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String,
    propertyId: json['propertyId'] as String,
    floorId: json['floorId'] as String,
    roomNumber: json['roomNumber'] as String,
    roomType: json['roomType'] as String? ?? 'single',
    sharingCapacity: json['sharingCapacity'] as int? ?? 1,
    rentAmount: parseNum(json['rentAmount']),
    mrpAmount: parseNum(json['mrpAmount']),
    beds: (json['beds'] as List?)?.map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
  );
}

/// Mirrors server's BedStatus enum: VACANT/RESERVED/OCCUPIED/BLOCKED.
class Bed {
  Bed({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.bedLabel,
    required this.status,
    this.rentAmount,
    this.reservedUntil,
    this.blockedReason,
  });

  final String id;
  final String propertyId;
  final String roomId;
  final String bedLabel;
  final String status;
  final double? rentAmount;
  final DateTime? reservedUntil;
  final String? blockedReason;

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
    id: json['id'] as String,
    propertyId: json['propertyId'] as String,
    roomId: json['roomId'] as String,
    bedLabel: json['bedLabel'] as String,
    status: json['status'] as String? ?? 'VACANT',
    rentAmount: json['rentAmount'] == null ? null : parseNum(json['rentAmount']),
    reservedUntil: json['reservedUntil'] == null ? null : DateTime.tryParse(json['reservedUntil'] as String),
    blockedReason: json['blockedReason'] as String?,
  );
}
