import 'pg_model.dart';

typedef UserRole = String;

class UserRoleValues {
  static const owner = 'owner';
  static const manager = 'manager';
  static const tenant = 'tenant';
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.photoURL,
    this.role,
    this.pgId,
    this.authProvider = 'phone',
    this.onboarded = false,
    this.pushToken,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String? email;
  final String? photoURL;
  final String? role;
  final String? pgId;
  final String authProvider;
  final bool onboarded;
  final String? pushToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      email: json['email'] as String?,
      photoURL: json['photoURL'] as String?,
      role: json['role'] as String?,
      pgId: json['pgId'] as String?,
      authProvider: (json['authProvider'] ?? 'phone') as String,
      onboarded: json['onboarded'] == true,
      pushToken: json['pushToken'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': email,
        'photoURL': photoURL,
        'role': role,
        'pgId': pgId,
        'authProvider': authProvider,
        'onboarded': onboarded,
        'pushToken': pushToken,
      };

  UserModel copyWith({
    String? name,
    String? phone,
    String? role,
    String? pgId,
    bool? onboarded,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email,
      photoURL: photoURL,
      role: role ?? this.role,
      pgId: pgId ?? this.pgId,
      authProvider: authProvider,
      onboarded: onboarded ?? this.onboarded,
      pushToken: pushToken,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
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

class AuthResult {
  const AuthResult({
    required this.token,
    required this.refreshToken,
    required this.uid,
    required this.isNewUser,
    this.role,
    this.pgId,
    this.hasInvite = false,
    this.inviteId,
  });

  final String token;
  final String refreshToken;
  final String uid;
  final bool isNewUser;
  final String? role;
  final String? pgId;
  final bool hasInvite;
  final String? inviteId;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String? ?? '',
      uid: json['uid'] as String,
      isNewUser: json['isNewUser'] == true,
      role: json['role'] as String?,
      pgId: json['pgId'] as String?,
      hasInvite: json['hasInvite'] == true,
      inviteId: json['inviteId'] as String?,
    );
  }
}

class MeResponse {
  const MeResponse({required this.user, this.pg});

  final UserModel user;
  final PgModel? pg;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      pg: json['pg'] != null
          ? PgModel.fromJson(json['pg'] as Map<String, dynamic>)
          : null,
    );
  }
}
