import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as fc;

import '../data/countries.dart';
import '../models/enums.dart';
import 'rides_service.dart';

/// Registro con correo, contrasena, nombre, apellido, edad y celular con
/// prefijo de pais (Panama +507 por defecto). El codigo de WhatsApp queda
/// disponible para verificar el celular mas adelante, no es la puerta de entrada.
class AuthService {
  AuthService({FirebaseAuth? auth, RidesService? ridesService})
      : _auth = auth ?? FirebaseAuth.instance,
        _rides = ridesService;

  final FirebaseAuth _auth;
  final RidesService? _rides;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Crea la cuenta y guarda el perfil en users/{uid}.
  Future<String> register({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required int edad,
    required String celular,
    required Country pais,
    required Role role,
  }) async {
    final rides = _rides;
    if (rides == null) {
      throw const AuthException('No pudimos conectar con la base de datos.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _cleanEmail(email),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('No pudimos crear la cuenta.');
      }

      await rides.saveProfile(
        nombre: nombre,
        apellido: apellido,
        edad: edad,
        celular: celular,
        pais: pais,
        role: role,
      );
      await user.updateDisplayName('$nombre $apellido');
      return user.uid;
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException(authErrorMessage(error));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _cleanEmail(email),
        password: password,
      );
    } catch (error) {
      throw AuthException(authErrorMessage(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: _cleanEmail(email));
    } catch (error) {
      throw AuthException(authErrorMessage(error));
    }
  }

  Future<void> signOut() => _auth.signOut();

  static String _cleanEmail(String email) => email.trim().toLowerCase();

  /// Hash del token de push: en devices/{hash} no guardamos el token en crudo.
  static String deviceHash(String token) =>
      sha256.convert(utf8.encode(token)).toString().substring(0, 32);
}

/// Traduce los codigos de FirebaseAuth a un mensaje que sirva en la app.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene cuenta. Entra con tu contrasena.';
      case 'weak-password':
        return 'La contrasena necesita al menos 6 caracteres.';
      case 'invalid-email':
        return 'Ese correo no es valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta esta desactivada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'network-request-failed':
        return 'Sin conexion. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El correo no esta habilitado para entrar.';
      default:
        return 'No pudimos iniciar sesion. Intenta de nuevo.';
    }
  }
  if (error is AuthException) return error.message;
  return 'No pudimos iniciar sesion. Intenta de nuevo.';
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Inicializa Firebase. Sin google-services.json real esto truena y la app
/// muestra la pantalla de "falta configurar Firebase".
Future<void> bootFirebase() => fc.Firebase.initializeApp();