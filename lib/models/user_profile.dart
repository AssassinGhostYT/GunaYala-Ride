import '../data/countries.dart';
import 'enums.dart';

/// Perfil publico. El cliente escribe sus datos de registro; los contadores
/// (stats) y la insignia los escribe el servidor.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nombre,
    required this.apellido,
    required this.edad,
    required this.celular,
    required this.prefijo,
    required this.paisCodigo,
    required this.paisNombre,
    required this.role,
    this.photoUrl,
    this.ridesGiven = 0,
    this.ridesTaken = 0,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String uid;

  // Datos que pide el registro.
  final String nombre;
  final String apellido;
  final int edad;

  /// Solo el numero local, sin prefijo: 61234567.
  final String celular;

  /// Como el pais: +507. Se guarda aparte para no depender de la lista.
  final String prefijo;
  final String paisCodigo;
  final String paisNombre;

  final Role role;
  final String? photoUrl;

  final int ridesGiven;
  final int ridesTaken;
  final double? ratingAverage;
  final int ratingCount;

  /// Nombre completo, como lo ven los otros.
  String get name {
    final joined = '$nombre $apellido'.trim();
    return joined.isEmpty ? '' : joined;
  }

  /// Numero completo para llamar: +50761234567.
  String get telefono => '$prefijo$celular';

  /// Alias historico: las rides guardan driverPhone/riderPhone con esto.
  String get phone => telefono;

  bool get esPanama => paisCodigo == 'PA';

  bool get isDriver => role == Role.driver;

  bool get hasRating => ratingCount > 0 && ratingAverage != null;

  String get iniciales {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Country? get pais {
    for (final country in countriesForSignup()) {
      if (country.code == paisCodigo) return country;
    }
    return null;
  }

  static UserProfile empty(String uid) => UserProfile(
        uid: uid,
        nombre: '',
        apellido: '',
        edad: 0,
        celular: '',
        prefijo: kPanama.dialCode,
        paisCodigo: kPanama.code,
        paisNombre: kPanama.name,
        role: Role.rider,
      );

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final stats = (map['stats'] as Map<String, dynamic>?) ?? const {};
    final nombre = (map['nombre'] as String?) ?? '';
    final apellido = (map['apellido'] as String?) ?? '';
    // Cuentas viejas que solo guardaban name.
    final legacy = (map['name'] as String?) ?? '';
    final parts = legacy.trim().split(RegExp(r'\s+'));
    return UserProfile(
      uid: uid,
      nombre: nombre.isNotEmpty ? nombre : (parts.isEmpty ? '' : parts.first),
      apellido: apellido.isNotEmpty ? apellido : (parts.length > 1 ? parts.sublist(1).join(' ') : ''),
      edad: _toInt(map['edad']),
      celular: (map['celular'] as String?) ?? '',
      prefijo: (map['prefijo'] as String?) ?? kPanama.dialCode,
      paisCodigo: (map['paisCodigo'] as String?) ?? kPanama.code,
      paisNombre: (map['paisNombre'] as String?) ?? kPanama.name,
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
        'nombre': nombre,
        'apellido': apellido,
        'edad': edad,
        'celular': celular,
        'prefijo': prefijo,
        'paisCodigo': paisCodigo,
        'paisNombre': paisNombre,
        'telefono': telefono,
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