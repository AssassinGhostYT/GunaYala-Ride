import 'enums.dart';

/// Perfil publico. Los contadores (stats) los escribe el servidor.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.photoUrl,
    this.ridesGiven = 0,
    this.ridesTaken = 0,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String uid;
  final String name;
  final String phone;
  final Role role;
  final String? photoUrl;

  final int ridesGiven;
  final int ridesTaken;
  final double? ratingAverage;
  final int ratingCount;

  bool get isDriver => role == Role.driver;

  bool get hasRating => ratingCount > 0 && ratingAverage != null;

  static UserProfile empty(String uid) => UserProfile(
        uid: uid,
        name: '',
        phone: '',
        role: Role.rider,
      );

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final stats = (map['stats'] as Map<String, dynamic>?) ?? const {};
    return UserProfile(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      role: Role.parse(map['role'] as String?),
      photoUrl: map['photoUrl'] as String?,
      ridesGiven: _toInt(stats['ridesGiven']),
      ridesTaken: _toInt(stats['ridesTaken']),
      ratingAverage: _toDouble(stats['ratingAverage']),
      ratingCount: _toInt(stats['ratingCount']),
    );
  }

  /// Lo que el cliente puede escribir en users/{uid}. Ni stats ni role.
  Map<String, dynamic> editableFields({String? photoUrl}) => {
        if (name.isNotEmpty) 'name': name,
        if (phone.isNotEmpty) 'phone': phone,
        if (photoUrl != null || this.photoUrl != null) 'photoUrl': photoUrl ?? this.photoUrl,
      };

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }
}