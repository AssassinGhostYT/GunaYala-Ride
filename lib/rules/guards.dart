import '../models/enums.dart';

/// Las 7 reglas de negocio, en Dart puro, para que se puedan testear sin
/// Firebase. La misma logica se duplica en firestore.rules y en las Functions:
/// aqui esta la version que ve el usuario, no la de seguridad.
class Guards {
  const Guards._();

  /// Regla 1: sin insignia verificada no publicas.
  static bool canPublishRide({
    required bool isDriver,
    required VerificationStatus verificationStatus,
    required bool badgeActive,
  }) {
    if (!isDriver) return false;
    if (!verificationStatus.isVerified) return false;
    return badgeActive;
  }

  /// Regla 1: la insignia se apaga sola con un reporte grave.
  static bool badgeVisible({
    required VerificationStatus verificationStatus,
    required bool badgeActive,
  }) =>
      verificationStatus.isVerified && badgeActive;

  /// Regla 2: los cupos ofrecidos nunca superan los asientos fisicos.
  static bool seatsWithinVehicle({
    required int seatsTotal,
    required int vehicleSeats,
  }) =>
      seatsTotal >= 1 && seatsTotal <= vehicleSeats;

  /// Regla 2: nunca puedes ofrecer menos cupos de los que ya vendiste.
  static bool seatsNotBelowReserved({
    required int seatsTotal,
    required int seatsReserved,
  }) =>
      seatsTotal >= seatsReserved;

  /// Regla 3: el chat solo en abordaje y en camino.
  static bool chatAllowed(RideStatus status) =>
      status == RideStatus.boarding || status == RideStatus.inProgress;

  /// Regla 3: solo los del viaje escriben y leen.
  static bool isPartyOfRide({
    required String uid,
    required String driverId,
    required List<String> riderIds,
  }) =>
      uid == driverId || riderIds.contains(uid);

  /// Regla 4: cancelar un cupo devuelve el asiento.
  static int seatsAfterRelease({
    required int seatsReserved,
    required int seats,
  }) =>
      (seatsReserved - seats).clamp(0, 1 << 31);

  /// Regla 5: sin confirmacion del pasajero no hay reseña.
  static bool canReview({
    required RideStatus status,
    required bool riderConfirmed,
    required bool alreadyReviewed,
  }) =>
      status == RideStatus.completed && riderConfirmed && !alreadyReviewed;

  /// Regla 6: reporte grave apaga la insignia, no banea la cuenta.
  static bool turnsBadgeOff(String reason) => ReportReason.isGrave(reason);

  /// Regla 7: la llamada muestra el numero real. Si no hay numero guardado,
  /// mejor mostrar el dialer vacio que un numero falso.
  static bool canCallDriver(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8;
  }

  static int seatsLeft({
    required int seatsReserved,
    required int vehicleSeats,
  }) =>
      (vehicleSeats - seatsReserved).clamp(0, 1 << 31);

  static bool isFull({required int seatsReserved, required int vehicleSeats}) =>
      seatsReserved >= vehicleSeats;

  static bool hasLastSeat({required int seatsReserved, required int vehicleSeats}) =>
      seatsReserved == vehicleSeats - 1;
}