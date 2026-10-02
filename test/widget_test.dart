import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunayala_ride/models/enums.dart';
import 'package:gunayala_ride/models/ride.dart';
import 'package:gunayala_ride/widgets/ride_card.dart';

Ride _ride({required int seatsReserved, int seatsTotal = 10, int vehicleSeats = 14}) {
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
    departureAt: DateTime.now().add(const Duration(hours: 4)),
    seatsTotal: seatsTotal,
    seatsReserved: seatsReserved,
    riderIds: const [],
    status: RideStatus.scheduled,
    price: 10,
  );
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('la tarjeta muestra ruta, precio y chofer verificado', (tester) async {
    await tester.pumpWidget(
      _app(RideCard(ride: _ride(seatsReserved: 2, seatsTotal: 10), onTap: () {})),
    );

    expect(find.text('Puerto Armuelles'), findsOneWidget);
    expect(find.text('El Porvenir'), findsOneWidget);
    expect(find.text('Mangildo'), findsOneWidget);
    expect(find.text(r'$10.00'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('un viaje lleno sale como LLENO', (tester) async {
    await tester.pumpWidget(
      _app(RideCard(ride: _ride(seatsReserved: 10, seatsTotal: 10), onTap: () {})),
    );

    expect(find.text('LLENO'), findsOneWidget);
  });

  testWidgets('un solo cupo sale como ULTIMO CUPO', (tester) async {
    await tester.pumpWidget(
      _app(RideCard(ride: _ride(seatsReserved: 9, seatsTotal: 10), onTap: () {})),
    );

    expect(find.text('ULTIMO CUPO'), findsOneWidget);
  });

  testWidgets('la tarjeta avisa que el pago es por fuera', (tester) async {
    await tester.pumpWidget(
      _app(RideCard(ride: _ride(seatsReserved: 1, seatsTotal: 10), onTap: () {})),
    );

    expect(
      find.textContaining('directo con el chofer'),
      findsOneWidget,
    );
  });
}