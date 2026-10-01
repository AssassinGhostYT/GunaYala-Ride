import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/ride.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../rules/guards.dart';
import '../theme.dart';
import '../widgets/route_map.dart';

/// Publicar viaje (chofer). Regla 1 y 2 activas: sin insignia no entra, y los
/// cupos nunca pueden pasar de los asientos fisicos del carro.
class PublishTab extends StatefulWidget {
  const PublishTab({super.key});

  @override
  State<PublishTab> createState() => _PublishTabState();
}

class _PublishTabState extends State<PublishTab> {
  final _formKey = GlobalKey<FormState>();
  final _origin = TextEditingController();
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  final _price = TextEditingController();

  DateTime _departureAt = DateTime.now().add(const Duration(hours: 2));
  late int _seats;
  final Set<String> _payments = {'efectivo'};
  ({double lat, double lng})? _originPoint;
  ({double lat, double lng})? _destinationPoint;

  static const _prices = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

  @override
  void initState() {
    super.initState();
    _seats = 1;
  }

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    _notes.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureAt.isBefore(now) ? now : _departureAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_departureAt));
    if (time == null || !mounted) return;
    setState(() {
      _departureAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String? _guard(AuthProvider auth) {
    if (!auth.canPublish) {
      return 'Sin insignia verificada no publicas. Estado actual: '
          '${auth.driverVerification.status.label}.';
    }
    final vehicle = auth.vehicle;
    if (vehicle == null) return 'Primero registra tu carro en el perfil.';
    if (!Guards.seatsWithinVehicle(seatsTotal: _seats, vehicleSeats: vehicle.seats)) {
      return 'No puedes ofrecer $_seats cupos: ${vehicle.display} tiene ${vehicle.seats} asientos.';
    }
    if ((double.tryParse(_price.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) <= 0) {
      return 'Pone el precio del cupo.';
    }
    if (!_departureAt.isAfter(DateTime.now())) return 'La hora de salida debe ser futura.';
    return null;
  }

  Future<void> _publish(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final guard = _guard(auth);
    if (guard != null) {
      _snack(guard);
      return;
    }

    final vehicle = auth.vehicle!;
    final price = double.parse(_price.text.replaceAll(RegExp(r'[^0-9.]'), ''));

    final draft = Ride(
      id: '',
      driverId: auth.uid,
      driverName: '',
      driverPhone: '',
      driverVerified: false,
      vehicleId: vehicle.id,
      vehicleLabel: '',
      vehicleSeats: vehicle.seats,
      origin: _origin.text.trim(),
      destination: _destination.text.trim(),
      departureAt: _departureAt,
      seatsTotal: _seats,
      seatsReserved: 0,
      riderIds: const [],
      status: RideStatus.scheduled,
      price: price,
      paymentMethods: _payments.toList(growable: false),
      notes: _notes.text.trim(),
      originPoint: _originPoint,
      destinationPoint: _destinationPoint,
    );

    final rides = context.read<RidesProvider>();
    final rideId = await rides.publishRide(
      draft: draft,
      driver: auth.profile!,
      vehicle: vehicle,
      driverVerified: true,
    );

    if (!mounted) return;
    if (rideId == null) {
      _snack(rides.error ?? 'No pudimos publicar.');
      return;
    }

    _formKey.currentState?.reset();
    setState(() {
      _seats = 1;
      _notes.clear();
      _payments.clear();
      _payments.add('efectivo');
    });
    _snack('Viaje publicado.');
    rides.start();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final publishing = context.watch<RidesProvider>().publishing;
    final vehicle = auth.vehicle;
    final maxSeats = vehicle?.seats ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar viaje')),
      body: !auth.canPublish
          ? _BadgeGate(status: auth.driverVerification.status)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (vehicle != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, color: kCianOscuro),
                        title: Text(vehicle.display),
                        subtitle: Text('${vehicle.seats} asientos fisicos'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _origin,
                    decoration: const InputDecoration(
                      labelText: 'Sale de',
                      hintText: 'Puerto/armada/pueblo',
                      prefixIcon: Icon(Icons.trip_origin),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'De donde sales.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _destination,
                    decoration: const InputDecoration(
                      labelText: 'Va a',
                      hintText: 'Puerto/armada/pueblo',
                      prefixIcon: Icon(Icons.place),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'A donde vas.' : null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule),
                            title: const Text('Hora de salida'),
                            subtitle: Text('${_departureAt.day}/${_departureAt.month} '
                                '${_departureAt.hour.toString().padLeft(2, '0')}:'
                                '${_departureAt.minute.toString().padLeft(2, '0')}'),
                            trailing: const Icon(Icons.edit, size: 18),
                            onTap: _pickDeparture,
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.airline_seat_recline_normal),
                                const SizedBox(width: 8),
                                const Text('Cupos que ofreces'),
                                const Spacer(),
                                Text(
                                  maxSeats == 0 ? '--' : '$_seats de $maxSeats',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          if (maxSeats > 0)
                            Slider(
                              value: _seats.clamp(1, maxSeats).toDouble(),
                              min: 1,
                              max: maxSeats.toDouble(),
                              divisions: maxSeats > 1 ? maxSeats - 1 : null,
                              label: '$_seats',
                              onChanged: (value) => setState(() => _seats = value.round()),
                            ),
                          Text(
                            'Tope: $maxSeats asientos del carro. Los cupos vendidos no los puedes bajar.',
                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio por cupo',
                      prefixText: r'$ ',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pone el precio.' : null,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _prices
                        .map(
                          (p) => ActionChip(
                            label: Text('\$${p.toStringAsFixed(0)}'),
                            onPressed: () => setState(
                              () => _price.text = p.toStringAsFixed(2),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Como te pagan'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Efectivo'),
                        selected: _payments.contains('efectivo'),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _payments.add('efectivo');
                          } else {
                            _payments.remove('efectivo');
                          }
                        }),
                      ),
                      FilterChip(
                        label: const Text('Yapp directo'),
                        selected: _payments.contains('yapp'),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _payments.add('yapp');
                          } else {
                            _payments.remove('yapp');
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El pago es directo con el pasajero. La app no cobra ni procesa.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Aviso (opcional)',
                      hintText: 'Ej: salgo del puerto viejo a las 7',
                    ),
                  ),
                  const SizedBox(height: 16),
                  RoutePickerField(
                    label: 'Punto en el mapa (opcional)',
                    child: RouteMapPicker(
                      onPicked: (lat, lng) => setState(() => _originPoint = (lat: lat, lng: lng)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RoutePickerField(
                    label: 'Destino en el mapa (opcional)',
                    child: RouteMapPicker(
                      onPicked: (lat, lng) =>
                          setState(() => _destinationPoint = (lat: lat, lng: lng)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: publishing ? null : () => _publish(auth),
                    child: publishing
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publicar viaje'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class RoutePickerField extends StatelessWidget {
  const RoutePickerField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Sin insignia no hay formulario: se explica por que, sin rodeos.
class _BadgeGate extends StatelessWidget {
  const _BadgeGate({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_outlined, size: 72, color: kCianClaro),
            const SizedBox(height: 16),
            Text(
              'Necesitas la insignia verificada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Estado actual: ${status.label}. La insignia sale despues de que una '
              'persona revise tus documentos.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}