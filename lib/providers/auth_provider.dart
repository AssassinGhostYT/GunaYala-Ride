import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import '../services/rides_service.dart';
import '../services/verification_service.dart';

/// Estado global: quien entro, su perfil, su insignia y su carro.
/// Los contadores y el status de verificacion llegan del servidor.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required RidesService ridesService,
    required VerificationService verificationService,
  })  : _auth = authService,
        _rides = ridesService,
        _verification = verificationService {
    _userSub = _auth.authStateChanges.listen(_onUser);
  }

  final AuthService _auth;
  final RidesService _rides;
  final VerificationService _verification;

  StreamSubscription<User?>? _userSub;
  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<DriverVerification>? _verificationSub;
  StreamSubscription<Vehicle?>? _vehicleSub;

  User? _user;
  UserProfile? _profile;
  Vehicle? _vehicle;
  DriverVerification _driverVerification = const DriverVerification();
  bool _loading = true;
  String? _error;

  User? get user => _user;
  String get uid => _user?.uid ?? '';

  UserProfile? get profile => _profile;

  /// Chofer o pasajero. Antes del onboarding es null.
  Role? get role => _profile?.role;

  bool get isDriver => _profile?.isDriver ?? false;

  bool get loading => _loading;

  String? get error => _error;

  Vehicle? get vehicle => _vehicle;

  DriverVerification get driverVerification => _driverVerification;

  /// Regla 1: sin insignia no se publica.
  bool get canPublish =>
      _driverVerification.status.isVerified && _driverVerification.badgeActive;

  bool get isVerifiedDriver =>
      _driverVerification.status.isVerified && !_driverVerification.badgeSuspended;

  bool get needsOnboarding => _user != null && (_profile == null || _profile!.name.isEmpty);

  void _onUser(User? user) {
    _user = user;
    _profileSub?.cancel();
    _verificationSub?.cancel();
    _vehicleSub?.cancel();
    _profile = null;
    _vehicle = null;
    _driverVerification = const DriverVerification();

    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    _profileSub = _rides.watchProfile(user.uid).listen((profile) {
      _profile = profile;
      _loading = false;
      notifyListeners();
    });
    _verificationSub = _verification.watchDriverVerification().listen((value) {
      _driverVerification = value;
      notifyListeners();
    });
    _vehicleSub = _rides.watchVehicle().listen((vehicle) {
      _vehicle = vehicle;
      notifyListeners();
    });
  }

  Future<void> completeOnboarding({
    required String name,
    required String phone,
    required Role role,
    VehicleKind? vehicleKind,
    String? plate,
    int? seats,
  }) async {
    final current = _user;
    if (current == null) return;

    await _rides.saveProfile(name: name, phone: phone, role: role);

    if (role == Role.driver) {
      if (vehicleKind == null || (seats == null || seats < 1)) {
        throw const AuthException('El chofer tiene que registrar su carro.');
      }
      await _rides.saveVehicle(
        plate: (plate ?? '').trim().isEmpty ? 'SIN PLACA' : plate!.trim(),
        kind: vehicleKind,
        seats: seats,
      );
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _profile = null;
    _vehicle = null;
    _loading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _profileSub?.cancel();
    _verificationSub?.cancel();
    _vehicleSub?.cancel();
    super.dispose();
  }
}