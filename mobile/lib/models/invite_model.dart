import 'package:rentle/models/pg_model.dart';
import 'package:rentle/models/room_model.dart';

class InviteModel {
  const InviteModel({
    required this.inviteId,
    required this.pgId,
    required this.phone,
    required this.role,
    this.roomId,
    required this.status,
    required this.invitedBy,
    this.createdAt,
    this.expiresAt,
    this.pgName,
    this.pgAddress,
    this.roomNumber,
    this.inviterName,
    this.moveInDate,
    this.rentAmount,
    this.depositAmount,
    this.pg,
    this.room,
  });

  final String inviteId;
  final String pgId;
  final String phone;
  final String role;
  final String? roomId;
  final String status;
  final String invitedBy;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? pgName;
  final String? pgAddress;
  final String? roomNumber;
  final String? inviterName;
  final DateTime? moveInDate;
  final double? rentAmount;
  final double? depositAmount;
  final PgModel? pg;
  final RoomModel? room;

  InviteModel copyWithDetails({
    PgModel? pg,
    RoomModel? room,
    String? inviterName,
  }) {
    return InviteModel(
      inviteId: inviteId,
      pgId: pgId,
      phone: phone,
      role: role,
      roomId: roomId,
      status: status,
      invitedBy: invitedBy,
      createdAt: createdAt,
      expiresAt: expiresAt,
      pgName: pg?.name ?? pgName,
      pgAddress: pg?.address ?? pgAddress,
      roomNumber: room?.roomNumber ?? roomNumber,
      inviterName: inviterName ?? this.inviterName,
      moveInDate: moveInDate,
      rentAmount: rentAmount,
      depositAmount: depositAmount,
      pg: pg ?? this.pg,
      room: room ?? this.room,
    );
  }

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      inviteId: (json['inviteId'] ?? json['id'] ?? '') as String,
      pgId: (json['pgId'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'tenant') as String,
      roomId: json['roomId'] as String?,
      status: (json['status'] ?? 'pending') as String,
      invitedBy: (json['invitedBy'] ?? '') as String,
      createdAt: _parseDate(json['createdAt']),
      expiresAt: _parseDate(json['expiresAt']),
      pgName: json['pgName'] as String?,
      pgAddress: json['pgAddress'] as String?,
      roomNumber: json['roomNumber'] as String?,
      inviterName: json['inviterName'] as String?,
      moveInDate: _parseDate(json['moveInDate']),
      rentAmount: json['rentAmount'] != null
          ? (json['rentAmount'] as num).toDouble()
          : null,
      depositAmount: json['depositAmount'] != null
          ? (json['depositAmount'] as num).toDouble()
          : null,
      pg: json['pg'] != null
          ? PgModel.fromJson(json['pg'] as Map<String, dynamic>)
          : null,
      room: json['room'] != null
          ? RoomModel.fromJson(json['room'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'inviteId': inviteId,
        'pgId': pgId,
        'phone': phone,
        'role': role,
        'roomId': roomId,
        'status': status,
        'invitedBy': invitedBy,
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
