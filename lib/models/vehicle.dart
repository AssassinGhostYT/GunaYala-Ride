import 'enums.dart';

class Vehicle {
  const Vehicle({
    required this.id,
    required this.driverId,
    required this.plate,
    required this.kind,
    required this.seats,
    this.label = '',
    this.color = '',
    this.photoUrl,
  });

  final String id;
  final String driverId;

  /// Placa o identificacion. Los 4x4 y las panga no siempre traen placa.
  final String plate;
  final VehicleKind kind;

  /// Asientos fisicos. Es el techo de cupos: nunca se ofrece mas de esto.
  final int seats;
  final String label;
  final String color;
  final String? photoUrl;

  String get display => label.isNotEmpty ? '$label $plate' : plate;

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) => Vehicle(
        id: id,
        driverId: (map['driverId'] as String?) ?? '',
        plate: (map['plate'] as String?) ?? '',
        kind: VehicleKind.parse(map['kind'] as String?),
        seats: _toInt(map['seats']),
        label: (map['label'] as String?) ?? '',
        color: (map['color'] as String?) ?? '',
        photoUrl: map['photoUrl'] as String?,
      );

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }
}

class DriverVerification {
  const DriverVerification({
    this.status = VerificationStatus.none,
    this.note = '',
    this.badgeActive = false,
    this.badgeSuspended = false,
    this.badgeSuspendedReason = '',
    this.pendingHumanReview = false,
  });

  final VerificationStatus status;
  final String note;
  final bool badgeActive;
  final bool badgeSuspended;
  final String badgeSuspendedReason;
  final bool pendingHumanReview;

  factory DriverVerification.fromMap(Map<String, dynamic> map) =>
      DriverVerification(
        status: VerificationStatus.parse(map['status'] as String?),
        note: (map['note'] as String?) ?? '',
        badgeActive: map['badgeActive'] == true,
        badgeSuspended: map['badgeSuspended'] == true,
        badgeSuspendedReason: (map['badgeSuspendedReason'] as String?) ?? '',
        pendingHumanReview: map['pendingHumanReview'] == true,
      );

  static DriverVerification fromDoc(
    Map<String, dynamic>? map,
  ) =>
      DriverVerification.fromMap(map ?? const {});
}