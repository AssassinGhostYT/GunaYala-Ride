import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' as fc;

import '../config.dart';

/// Login por WhatsApp: la app pide un codigo de 6 digitos, la Function lo
/// manda por WhatsApp y devuelve un custom token. No hay contrasenas.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> sendOtp(String phone) async {
    await _functions.httpsCallable('sendOtp').call<Map<String, dynamic>>(
      {'phone': phone},
    );
  }

  Future<String> verifyOtp({required String phone, required String code}) async {
    final cleaned = code.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != AppConfig.otpDigits) {
      throw AuthException('El codigo son ${AppConfig.otpDigits} digitos.');
    }

    final result = await _functions
        .httpsCallable('verifyOtp')
        .call<Map<String, dynamic>>({'phone': phone, 'code': cleaned});

    final token = result.data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('No pudimos validar el codigo. Intenta de nuevo.');
    }

    await _auth.signInWithCustomToken(token);
    return result.data['uid'] as String? ?? _auth.currentUser!.uid;
  }

  Future<void> signOut() => _auth.signOut();

  /// Hash del token de push: en devices/{hash} no guardamos el token en crudo.
  static String deviceHash(String token) =>
      sha256.convert(utf8.encode(token)).toString().substring(0, 32);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> bootFirebase() => fc.Firebase.initializeApp();