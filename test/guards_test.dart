import 'package:flutter_test/flutter_test.dart';
import 'package:gunayala_ride/models/enums.dart';
import 'package:gunayala_ride/rules/guards.dart';

/// Las 7 reglas de negocio, testeadas sin Firebase.
void main() {
  group('Regla 1: insignia antes de publicar', () {
    test('sin insignia verificada no publica', () {
      expect(
        Guards.canPublishRide(
          isDriver: true,
          verificationStatus: VerificationStatus.pending,
          badgeActive: false,
        ),
        isFalse,
      );
    });

    test('insignia verificada publica', () {
      expect(
        Guards.canPublishRide(
          isDriver: true,
          verificationStatus: VerificationStatus.verified,
          badgeActive: true,
        ),
        isTrue,
      );
    });

    test('el pasajero nunca publica aunque tenga insignia', () {
      expect(
        Guards.canPublishRide(
          isDriver: false,
          verificationStatus: VerificationStatus.verified,
          badgeActive: true,
        ),
        isFalse,
      );
    });

    test('la insignia apagada por reporte grave no publica', () {
      expect(
        Guards.canPublishRide(
          isDriver: true,
          verificationStatus: VerificationStatus.verified,
          badgeActive: false,
        ),
        isFalse,
      );
    });
  });

  group('Regla 2: cupos contra asientos fisicos', () {
    test('no se puede ofrecer mas que los asientos', () {
      expect(Guards.seatsWithinVehicle(seatsTotal: 15, vehicleSeats: 14), isFalse);
      expect(Guards.seatsWithinVehicle(seatsTotal: 14, vehicleSeats: 14), isTrue);
      expect(Guards.seatsWithinVehicle(seatsTotal: 1, vehicleSeats: 4), isTrue);
    });

    test('no se puede ofrecer cero cupos', () {
      expect(Guards.seatsWithinVehicle(seatsTotal: 0, vehicleSeats: 14), isFalse);
    });

    test('no se puede bajar de los cupos ya vendidos', () {
      expect(Guards.seatsNotBelowReserved(seatsTotal: 3, seatsReserved: 5), isFalse);
      expect(Guards.seatsNotBelowReserved(seatsTotal: 5, seatsReserved: 5), isTrue);
      expect(Guards.seatsNotBelowReserved(seatsTotal: 8, seatsReserved: 5), isTrue);
    });
  });

  group('Regla 3: chat solo en abordaje o en camino', () {
    test('cerrado antes y despues del viaje', () {
      expect(Guards.chatAllowed(RideStatus.scheduled), isFalse);
      expect(Guards.chatAllowed(RideStatus.completed), isFalse);
      expect(Guards.chatAllowed(RideStatus.cancelled), isFalse);
    });

    test('abierto en boarding e inProgress', () {
      expect(Guards.chatAllowed(RideStatus.boarding), isTrue);
      expect(Guards.chatAllowed(RideStatus.inProgress), isTrue);
    });

    test('solo los del viaje', () {
      const driverId = 'chofer1';
      const riders = ['pasajero1', 'pasajero2'];
      expect(
        Guards.isPartyOfRide(uid: driverId, driverId: driverId, riderIds: riders),
        isTrue,
      );
      expect(
        Guards.isPartyOfRide(uid: 'pasajero1', driverId: driverId, riderIds: riders),
        isTrue,
      );
      expect(
        Guards.isPartyOfRide(uid: 'ajeno', driverId: driverId, riderIds: riders),
        isFalse,
      );
    });
  });

  group('Regla 4: cancelar devuelve el asiento', () {
    test('resta el cupo y nunca baja de cero', () {
      expect(Guards.seatsAfterRelease(seatsReserved: 5, seats: 2), 3);
      expect(Guards.seatsAfterRelease(seatsReserved: 1, seats: 2), 0);
    });
  });

  group('Regla 5: resena solo con confirmacion', () {
    test('sin riderConfirmed no hay resena', () {
      expect(
        Guards.canReview(
          status: RideStatus.completed,
          riderConfirmed: false,
          alreadyReviewed: false,
        ),
        isFalse,
      );
    });

    test('con confirmacion y viaje terminado si', () {
      expect(
        Guards.canReview(
          status: RideStatus.completed,
          riderConfirmed: true,
          alreadyReviewed: false,
        ),
        isTrue,
      );
    });

    test('una resena por pasajero', () {
      expect(
        Guards.canReview(
          status: RideStatus.completed,
          riderConfirmed: true,
          alreadyReviewed: true,
        ),
        isFalse,
      );
    });
  });

  group('Regla 6: reporte grave apaga la insignia', () {
    test('amenaza y manejo peligroso son graves', () {
      expect(Guards.turnsBadgeOff('amenaza'), isTrue);
      expect(Guards.turnsBadgeOff('manejo_peligroso'), isTrue);
      expect(Guards.turnsBadgeOff('arma'), isTrue);
    });

    test('no_show no apaga la insignia', () {
      expect(Guards.turnsBadgeOff('no_show'), isFalse);
      expect(Guards.turnsBadgeOff('otro'), isFalse);
    });
  });

  group('Regla 7: llamada con el numero real', () {
    test('numero valido permite llamar', () {
      expect(Guards.canCallDriver('+50760001234'), isTrue);
      expect(Guards.canCallDriver('60001234'), isTrue);
    });

    test('sin numero no se inventa', () {
      expect(Guards.canCallDriver(null), isFalse);
      expect(Guards.canCallDriver(''), isFalse);
      expect(Guards.canCallDriver('123'), isFalse);
    });
  });

  group('Gestor de cupos', () {
    test('libres, lleno y ultimo cupo', () {
      expect(Guards.seatsLeft(seatsReserved: 2, vehicleSeats: 5), 3);
      expect(Guards.isFull(seatsReserved: 5, vehicleSeats: 5), isTrue);
      expect(Guards.hasLastSeat(seatsReserved: 4, vehicleSeats: 5), isTrue);
      expect(Guards.hasLastSeat(seatsReserved: 3, vehicleSeats: 5), isFalse);
    });
  });

  group('Tipos de carro de Guna Yala', () {
    test('los asientos tipicos no pasan de 30', () {
      for (final kind in VehicleKind.values) {
        expect(kind.typicalSeats, lessThanOrEqualTo(30));
        expect(kind.typicalSeats, greaterThanOrEqualTo(4));
      }
    });
  });
}