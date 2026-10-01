import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../models/enums.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../rules/guards.dart';

/// Todas las escrituras de rides, solicitudes y chat.
/// Los contadores (seatsReserved, riderIds, stats) no se tocan aqui: eso lo
/// hacen onSeatAccepted / onSeatReleased / onRideFinished en el servidor.
class RidesService {
  RidesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  // ---------- Perfil ----------

  Stream<UserProfile?> watchProfile(String uid) {
    return _db.doc('users/$uid').snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null,
        );
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    required Role role,
  }) async {
    await _db.doc('users/$_uid').set({
      'name': name,
      'phone': phone,
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveVehicle({
    required String plate,
    required VehicleKind kind,
    required int seats,
    String label = '',
  }) async {
    await _db.collection('vehicles').add({
      'driverId': _uid,
      'plate': plate,
      'kind': kind.label,
      'seats': seats,
      'label': label,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Vehicle?> watchVehicle() {
    return _db
        .collection('vehicles')
        .where('driverId', isEqualTo: _uid)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return Vehicle.fromMap(doc.id, doc.data());
    });
  }

  // ---------- Publicar ----------

  /// Regla 1 + Regla 2 aplicadas antes de escribir. Si el chofer no tiene
  /// insignia no se crea nada, ni en Firestore ni en la UI.
  Future<String> publishRide({
    required Ride draft,
    required UserProfile driver,
    required Vehicle vehicle,
    required bool driverVerified,
  }) async {
    final error = validatePublish(draft: draft, driver: driver, vehicle: vehicle);
    if (error != null) throw RideException(error);

    final ref = _db.collection('rides').doc();
    await ref.set({
      ...draft.publishFields(
        driverName: driver.name,
        driverPhone: driver.phone,
        driverVerified: driverVerified,
        vehicleLabel: vehicle.display,
        vehicleSeats: vehicle.seats,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'seatsUpdatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Devuelve null si se puede publicar, o el motivo por el que no.
  String? validatePublish({
    required Ride draft,
    required UserProfile driver,
    required Vehicle vehicle,
  }) {
    if (!driver.isDriver) return 'Solo un chofer publica viajes.';
    if (draft.origin.trim().isEmpty || draft.destination.trim().isEmpty) {
      return 'Ponto de salida y destino son obligatorios.';
    }
    if (!Guards.seatsWithinVehicle(
      seatsTotal: draft.seatsTotal,
      vehicleSeats: vehicle.seats,
    )) {
      return 'No puedes ofrecer ${draft.seatsTotal} cupos: '
          '${vehicle.display} tiene ${vehicle.seats} asientos.';
    }
    if (draft.price <= 0) return 'Pone el precio del cupo.';
    if (!draft.departureAt.isAfter(DateTime.now())) {
      return 'La hora de salida debe ser futura.';
    }
    return null;
  }

  Future<void> cancelRide(String rideId) => _db
      .doc('rides/$rideId')
      .update({'status': RideStatus.cancelled.name, 'cancelledAt': FieldValue.serverTimestamp()});

  Future<void> advanceRideStatus(String rideId, RideStatus next) =>
      _db.doc('rides/$rideId').update({'status': next.name});

  Future<void> confirmRideFinished(String rideId) => _db.doc('rides/$rideId').update({
        'riderConfirmed': true,
        'confirmedByRiderAt': FieldValue.serverTimestamp(),
      });

  /// Regla 5: la confirmacion del pasajero abre la resena (onRideFinished).
  Future<void> leaveReview({
    required String reviewId,
    required int rating,
    String comment = '',
  }) {
    return _db.doc('reviews/$reviewId').update({
      'rating': rating.clamp(1, 5),
      'comment': comment,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Buscar ----------

  /// Los viajes llenos no salen en la lista.
  Stream<List<Ride>> searchRides({String? origin}) {
    Query<Map<String, dynamic>> query = _db
        .collection('rides')
        .where('status', isEqualTo: RideStatus.scheduled.name)
        .where('seatsReserved', isLessThan: 30)
        .orderBy('departureAt');

    if (origin != null && origin.isNotEmpty) {
      query = query.where('origin', isEqualTo: origin);
    }

    return query.snapshots().map((snap) {
      final rides = snap.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .where((ride) => !ride.isFull)
          .toList();
      rides.sort((a, b) => a.departureAt.compareTo(b.departureAt));
      return rides;
    });
  }

  Stream<Ride?> watchRide(String rideId) {
    return _db.doc('rides/$rideId').snapshots().map(
          (snap) => snap.exists ? Ride.fromMap(rideId, snap.data()!) : null,
        );
  }

  /// Mis viajes como chofer.
  Stream<List<Ride>> watchDriverRides() {
    return _db
        .collection('rides')
        .where('driverId', isEqualTo: _uid)
        .orderBy('departureAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Ride.fromMap(doc.id, doc.data())).toList());
  }

  /// Mis cupos: los viajes donde ya tengo asiento.
  Stream<List<Ride>> watchMyBookings() {
    return _db
        .collectionGroup('rides')
        .where('riderIds', arrayContains: _uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Ride.fromMap(doc.id, doc.data())).toList());
  }

  // ---------- Solicitudes ----------

  Future<void> requestSeat({
    required String rideId,
    required UserProfile rider,
    required int seats,
  }) async {
    await _db.doc('rides/$rideId/requests/$_uid').set({
      'riderId': _uid,
      'riderName': rider.name,
      'riderPhone': rider.phone,
      'seats': seats.clamp(1, AppConfig.maxSeatsPerRide),
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<RideRequest>> watchRequests(String rideId) {
    return _db
        .collection('rides/$rideId/requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RideRequest.fromMap(doc.id, {...doc.data(), 'rideId': rideId}))
            .toList());
  }

  /// Aceptar no suma asientos aqui: el trigger onSeatReleased/onSeatAccepted
  /// ajusta seatsReserved y riderIds en una transaccion del servidor.
  Future<void> acceptRequest(String rideId, String requestId) => _db
      .doc('rides/$rideId/requests/$requestId')
      .update({
        'status': RequestStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

  Future<void> rejectRequest(String rideId, String requestId) => _db
      .doc('rides/$rideId/requests/$requestId')
      .update({
        'status': RequestStatus.rejected.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

  /// Regla 4: cancelar devuelve el asiento (onSeatReleased).
  Future<void> cancelRequest(String rideId, String requestId) => _db
      .doc('rides/$rideId/requests/$requestId')
      .update({
        'status': RequestStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

  // ---------- Chat ----------

  /// Regla 3: chat solo entre los del viaje y solo en abordaje/en camino.
  bool chatOpenFor(Ride ride) =>
      Guards.chatAllowed(ride.status) &&
      Guards.isPartyOfRide(
        uid: _uid,
        driverId: ride.driverId,
        riderIds: ride.riderIds,
      );

  Stream<List<ChatMessage>> watchChat(String rideId) {
    return _db
        .collection('rides/$rideId/chat')
        .orderBy('sentAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromMap(doc.id, doc.data(), _uid))
            .toList());
  }

  Future<void> sendMessage({
    required String rideId,
    required String senderName,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _db.collection('rides/$rideId/chat').add({
      'senderId': _uid,
      'senderName': senderName,
      'text': clean.length > AppConfig.chatMaxLength
          ? clean.substring(0, AppConfig.chatMaxLength)
          : clean,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Reportes y bloqueos ----------

  /// El reportado nunca lee estos documentos.
  Future<void> report(SafetyReport report, {required String reporterName}) {
    return _db.collection('reports').add(
          report.toMap(reporterName: reporterName, now: DateTime.now()),
        );
  }

  Future<void> block(String otherUid) => _db.doc('users/$_uid/blocked/$otherUid').set({
        'blockedAt': FieldValue.serverTimestamp(),
      });

  Future<void> unblock(String otherUid) => _db.doc('users/$_uid/blocked/$otherUid').delete();

  Stream<Set<String>> watchBlocked() {
    return _db
        .collection('users/$_uid/blocked')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }

  // ---------- Confianza del chofer ----------

  Stream<List<DriverReview>> watchDriverReviews(String driverId) {
    return _db
        .collection('reviews')
        .where('driverId', isEqualTo: driverId)
        .where('rating', isGreaterThan: 0)
        .orderBy('rating', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DriverReview.fromMap(doc.id, doc.data())).toList());
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _db.doc('users/$uid').get();
    return snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null;
  }
}

class RideException implements Exception {
  const RideException(this.message);

  final String message;

  @override
  String toString() => message;
}