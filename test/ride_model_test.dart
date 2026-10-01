import 'package:flutter_test/flutter_test.dart';
import 'package:gunayala_ride/models/enums.dart';
import 'package:gunayala_ride/models/ride.dart';
import 'package:gunayala_ride/models/user_profile.dart';

Ride _ride({
  int seatsTotal = 10,
  int seatsReserved = 0,
  int vehicleSeats = 14,
  RideStatus status = RideStatus.scheduled,
  List<String> riderIds = const [],
}) {
  final now = DateTime.now();
  return Ride(
    id: 'viaje1',
    driverId: 'chofer1',
    driverName: 'Mangildo',
    driverPhone: '+50760001111',
    driverVerified: true,
    vehicleId: 'panga1',
    vehicleLabel: 'panga ABC-123',
    vehicleSeats: vehicleSeats,
    origin: 'Puerto Armuelles',
    destination: 'El Porvenir',
    departureAt: now.add(const Duration(hours: 3)),
    seatsTotal: seatsTotal,
    seatsReserved: seatsReserved,
    riderIds: riderIds,
    status: status,
    price: 10,
    riderConfirmed: false,
  );
}

void main() {
  group('Ride desde Firestore', () {
    test('lee el mapa sin romperse', () {
      final ride = Ride.fromMap('viaje1', {
        'driverId': 'chofer1',
        'driverName': 'Mangildo',
        'driverPhone': '+50760001111',
        'driverVerified': true,
        'vehicleId': 'panga1',
        'vehicleSeats': 14,
        'origin': 'Puerto Armuelles',
        'destination': 'El Porvenir',
        'departureAt': DateTime.now(),
        'seatsTotal': 10,
        'seatsReserved': 3,
        'riderIds': ['a', 'b'],
        'status': 'scheduled',
        'price': 10.0,
        'paymentMethods': ['efectivo', 'yapp'],
      });

      expect(ride.id, 'viaje1');
      expect(ride.driverVerified, isTrue);
      expect(ride.riderIds, ['a', 'b']);
      expect(ride.status, RideStatus.scheduled);
      expect(ride.seatsLeft, 11);
    });

    test('campos que faltan no rompen el modelo', () {
      final ride = Ride.fromMap('x', {'origin': 'a'});
      expect(ride.seatsReserved, 0);
      expect(ride.riderIds, isEmpty);
      expect(ride.paymentMethods, ['efectivo']);
    });
  });

  group('Gestor de cupos en el viaje', () {
    test('lleno deja de aparecer en la lista', () {
      final ride = _ride(seatsReserved: 14, vehicleSeats: 14);
      expect(ride.isFull, isTrue);
      expect(ride.seatsLeft, 0);
    });

    test('ultimo cupo avisado', () {
      final ride = _ride(seatsReserved: 13, vehicleSeats: 14);
      expect(ride.isLastSeat, isTrue);
      expect(ride.isFull, isFalse);
    });

    test('un viaje lleno ya no es reservable', () {
      expect(_ride(seatsReserved: 14, vehicleSeats: 14).isBookable, isFalse);
      expect(_ride().isBookable, isTrue);
    });

    test('un viaje terminado ya no es reservable', () {
      expect(_ride(status: RideStatus.completed).isBookable, isFalse);
      expect(_ride(status: RideStatus.cancelled).isBookable, isFalse);
    });
  });

  group('Al publicar, los contadores arrancan en cero', () {
    test('seatsReserved 0 y riderIds vacio', () {
      final ride = _ride();
      final fields = ride.publishFields(
        driverName: 'Mangildo',
        driverPhone: '+50760001111',
        driverVerified: true,
        vehicleLabel: 'panga ABC-123',
        vehicleSeats: 14,
      );

      expect(fields['seatsReserved'], 0);
      expect(fields['riderIds'], isEmpty);
      expect(fields['status'], 'scheduled');
      expect(fields['seatsTotal'], 10);
    });
  });

  group('UserProfile', () {
    test('lee stats del servidor', () {
      final profile = UserProfile.fromMap('u1', {
        'name': 'Yari',
        'phone': '+50760002222',
        'role': 'driver',
        'stats': {'ridesGiven': 12, 'ratingAverage': 4.5, 'ratingCount': 8},
      });

      expect(profile.isDriver, isTrue);
      expect(profile.ridesGiven, 12);
      expect(profile.hasRating, isTrue);
      expect(profile.ratingAverage, 4.5);
    });

    test('rol desconocido cae en pasajero', () {
      expect(Role.parse('raro'), Role.rider);
      expect(UserProfile.fromMap('u2', {'name': 'x'}).isDriver, isFalse);
    });
  });
}