import '../data/countries.dart';
import 'enums.dart';
import 'user_profile.dart';

class Ride {
  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverVerified,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.vehicleSeats,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.seatsTotal,
    required this.seatsReserved,
    required this.riderIds,
    required this.status,
    required this.price,
    this.paymentMethods = const ['efectivo'],
    this.riderConfirmed = false,
    this.confirmedByRiderAt,
    this.driverRating,
    this.notes = '',
    this.originPoint,
    this.destinationPoint,
    this.createdAt,
  });

  final String id;

  // Copia en el viaje: el pasajero necesita ver la ficha sin abrir otro doc.
  final String driverId;
  final String driverName;
  final String driverPhone;
  final bool driverVerified;

  final String vehicleId;
  final String vehicleLabel;
  final int vehicleSeats;

  final String origin;
  final String destination;
  final DateTime departureAt;

  /// Regla 2: <= vehicleSeats.
  final int seatsTotal;

  /// Intocable por el chofer. Lo mueven los triggers.
  final int seatsReserved;
  final List<String> riderIds;

  final RideStatus status;
  final double price;
  final List<String> paymentMethods;

  /// Regla 5: sin esto no hay reseña.
  final bool riderConfirmed;
  final DateTime? confirmedByRiderAt;

  final double? driverRating;
  final String notes;
  final ({double lat, double lng})? originPoint;
  final ({double lat, double lng})? destinationPoint;
  final DateTime? createdAt;

  /// Cupos que quedan de los que el chofer ofrecio (no de los asientos).
  int get seatsLeft => (seatsTotal - seatsReserved).clamp(0, 1 << 31);

  bool get isFull => seatsReserved >= seatsTotal;

  /// Ultimo cupo OFRECIDO (no el ultimo asiento del carro).
  bool get isLastSeat => seatsReserved == seatsTotal - 1;

  bool get isBookable =>
      status == RideStatus.scheduled && !isFull && departureAt.isAfter(DateTime.now());

  bool get hasGps => originPoint != null && destinationPoint != null;

  factory Ride.fromMap(String id, Map<String, dynamic> map) => Ride(
        id: id,
        driverId: (map['driverId'] as String?) ?? '',
        driverName: (map['driverName'] as String?) ?? '',
        driverPhone: (map['driverPhone'] as String?) ?? '',
        driverVerified: map['driverVerified'] == true,
        vehicleId: (map['vehicleId'] as String?) ?? '',
        vehicleLabel: (map['vehicleLabel'] as String?) ?? '',
        vehicleSeats: _toInt(map['vehicleSeats']),
        origin: (map['origin'] as String?) ?? '',
        destination: (map['destination'] as String?) ?? '',
        departureAt: _toDate(map['departureAt']) ?? DateTime.now(),
        seatsTotal: _toInt(map['seatsTotal']),
        seatsReserved: _toInt(map['seatsReserved']),
        riderIds: (map['riderIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        status: RideStatus.parse(map['status'] as String?),
        price: _toDouble(map['price']),
        paymentMethods: (map['paymentMethods'] as List<dynamic>? ?? const ['efectivo'])
            .map((e) => e.toString())
            .toList(growable: false),
        riderConfirmed: map['riderConfirmed'] == true,
        confirmedByRiderAt: _toDate(map['confirmedByRiderAt']),
        driverRating: _toDouble(map['driverRating']),
        notes: (map['notes'] as String?) ?? '',
        originPoint: _toPoint(map['originPoint']),
        destinationPoint: _toPoint(map['destinationPoint']),
        createdAt: _toDate(map['createdAt']),
      );

  /// El chofer escribe esto al publicar. Lo demas lo pone el servidor.
  Map<String, dynamic> publishFields({
    required String driverName,
    required String driverPhone,
    required bool driverVerified,
    required String vehicleLabel,
    required int vehicleSeats,
  }) =>
      {
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverVerified': driverVerified,
        'vehicleId': vehicleId,
        'vehicleLabel': vehicleLabel,
        'vehicleSeats': vehicleSeats,
        'origin': origin,
        'destination': destination,
        'departureAt': departureAt,
        'seatsTotal': seatsTotal,
        'price': price,
        'paymentMethods': paymentMethods,
        'notes': notes,
        'status': RideStatus.scheduled.name,
        'seatsReserved': 0,
        'riderIds': <String>[],
        if (originPoint != null)
          'originPoint': {'lat': originPoint!.lat, 'lng': originPoint!.lng},
        if (destinationPoint != null)
          'destinationPoint': {
            'lat': destinationPoint!.lat,
            'lng': destinationPoint!.lng,
          },
      };

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static ({double lat, double lng})? _toPoint(Object? value) {
    if (value is Map) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    }
    return null;
  }
}

class RiderSummary {
  const RiderSummary({
    required this.uid,
    required this.name,
    required this.phone,
  });

  final String uid;
  final String name;
  final String phone;

  factory RiderSummary.fromMap(String uid, Map<String, dynamic> map) => RiderSummary(
        uid: uid,
        name: (map['name'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
      );

  UserProfile toProfile() {
    final parts = name.trim().split(RegExp(r'\s+'));
    return UserProfile(
      uid: uid,
      nombre: parts.isEmpty ? '' : parts.first,
      apellido: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      edad: 0,
      celular: phone,
      prefijo: '',
      paisCodigo: kPanama.code,
      paisNombre: kPanama.name,
      role: Role.rider,
    );
  }
}