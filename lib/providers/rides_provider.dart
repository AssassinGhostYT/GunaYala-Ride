import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ride.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/rides_service.dart';

/// Estado de la pestana Buscar: la lista de viajes con cupo disponible.
class RidesProvider extends ChangeNotifier {
  RidesProvider({required RidesService ridesService}) : _rides = ridesService;

  final RidesService _rides;

  StreamSubscription<List<Ride>>? _sub;
  List<Ride> _rides = const [];
  bool _onlyWithSeats = true;
  bool _loading = true;
  String? _error;
  bool _publishing = false;

  List<Ride> get rides => _rides;

  bool get onlyWithSeats => _onlyWithSeats;

  bool get loading => _loading;

  String? get error => _error;

  bool get publishing => _publishing;

  /// Los viajes llenos no salen nunca.
  List<Ride> get visibleRides =>
      _onlyWithSeats ? _rides.where((ride) => !ride.isFull).toList() : _rides;

  void start() {
    _sub?.cancel();
    _loading = true;
    notifyListeners();
    _sub = _rides.searchRides().listen(
      (rides) {
        _rides = rides;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'No pudimos cargar los viajes.';
        _loading = false;
        notifyListeners();
      },
    );
  }

  void setOnlyWithSeats(bool value) {
    _onlyWithSeats = value;
    notifyListeners();
  }

  Future<String?> publishRide({
    required Ride draft,
    required UserProfile driver,
    required Vehicle vehicle,
    required bool driverVerified,
  }) async {
    _publishing = true;
    _error = null;
    notifyListeners();
    try {
      return await _rides.publishRide(
        draft: draft,
        driver: driver,
        vehicle: vehicle,
        driverVerified: driverVerified,
      );
    } on RideException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'No pudimos publicar el viaje.';
      return null;
    } finally {
      _publishing = false;
      notifyListeners();
    }
  }

  Future<bool> requestSeat({
    required String rideId,
    required UserProfile rider,
    required int seats,
  }) async {
    _error = null;
    notifyListeners();
    try {
      await _rides.requestSeat(rideId: rideId, rider: rider, seats: seats);
      return true;
    } on RideException catch (error) {
      _error = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'No pudimos enviar tu solicitud.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}