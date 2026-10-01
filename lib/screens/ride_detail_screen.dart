import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ride.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../rules/guards.dart';
import '../services/contact_service.dart';
import '../services/rides_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/route_map.dart';
import 'chat_screen.dart';
import 'driver_card.dart';
import 'requests_screen.dart';
import 'reviews_screen.dart';
import 'shield_screen.dart';

/// Detalle del viaje: ruta, chofer, carro, cupos, contacto, chat y resena.
class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    final auth = context.watch<AuthProvider>();

    return StreamBuilder<Ride?>(
      stream: rides.watchRide(rideId),
      builder: (context, snapshot) {
        final ride = snapshot.data;
        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Viaje')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final isDriver = ride.driverId == auth.uid;
        final hasSeat = ride.riderIds.contains(auth.uid);
        final chatOpen = rides.chatOpenFor(ride);
        final canLeaveReview = Guards.canReview(
          status: ride.status,
          riderConfirmed: ride.riderConfirmed,
          alreadyReviewed: false,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('${ride.origin} - ${ride.destination}'),
            actions: [
              IconButton(
                tooltip: 'Escudo',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ShieldScreen(ride: ride),
                  ),
                ),
                icon: const Icon(Icons.shield),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(ride: ride),
              const SizedBox(height: 16),
              RouteMapView(ride: ride),
              const SizedBox(height: 16),
              _PriceRow(ride: ride),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: kCianOscuro),
                  title: Text(ride.vehicleLabel),
                  subtitle: Text('${ride.vehicleSeats} asientos fisicos'),
                ),
              ),
              const SizedBox(height: 12),
              DriverCard(
                driverId: ride.driverId,
                name: ride.driverName,
                phone: ride.driverPhone,
                verified: ride.driverVerified,
              ),
              const SizedBox(height: 12),
              if (ride.notes.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.campaign, color: kMango),
                        const SizedBox(width: 10),
                        Expanded(child: Text(ride.notes)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _SeatsPanel(ride: ride, isDriver: isDriver),
              const SizedBox(height: 16),
              if (isDriver) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RequestsScreen(rideId: ride.id),
                    ),
                  ),
                  icon: const Icon(Icons.inbox),
                  label: const Text('Solicitudes y pasajeros'),
                ),
                const SizedBox(height: 8),
              ],
              if (chatOpen)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(ride: ride),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat del viaje'),
                )
              else
                const _ChatClosedNote(),
              const SizedBox(height: 8),
              if (!isDriver)
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await SharePlus.instance.share(
                      ShareParams(text: ContactService(ridesService: rides).shareText(ride)),
                    );
                    final ok = result.status == ShareResultStatus.success;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Viaje compartido.' : 'No se compartio.')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir viaje'),
                ),
              if (canLeaveReview && hasSeat) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewsScreen(ride: ride),
                    ),
                  ),
                  icon: const Icon(Icons.star_border),
                  label: const Text('Dejar resena'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: isDriver
              ? null
              : _RiderActionBar(ride: ride, hasSeat: hasSeat),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullLabel(ride.departureAt),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(relativeLabel(ride.departureAt)),
            const SizedBox(height: 12),
            _Line(icon: Icons.trip_origin, text: ride.origin, color: kCianOscuro),
            const SizedBox(height: 8),
            _Line(icon: Icons.place, text: ride.destination, color: kCoral),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCianOscuro.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ride.status.label,
                    style: const TextStyle(
                      color: kCianOscuro,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (ride.riderConfirmed)
                  const Chip(
                    label: Text('Confirmado por el pasajero'),
                    avatar: Icon(Icons.check, size: 16),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  money(ride.price),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kCianOscuro,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('por cupo'),
                const Spacer(),
                Text(seatsLabel(ride.vehicleSeats, ride.seatsReserved)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ride.paymentMethods
                  .map(
                    (method) => Chip(
                      label: Text(paymentLabel(method)),
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              paymentNotice,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatsPanel extends StatelessWidget {
  const _SeatsPanel({required this.ride, required this.isDriver});

  final Ride ride;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final left = ride.seatsLeft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cupos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Ofrecidos: ${ride.seatsTotal}'),
            Text('Vendidos: ${ride.seatsReserved} (no los modifica el chofer)'),
            Text('Libres: $left'),
            const SizedBox(height: 6),
            if (isDriver)
              const Text(
                'Los cupos vendidos no los puedes tocar ni bajar.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatClosedNote extends StatelessWidget {
  const _ChatClosedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'El chat se abre en abordaje y se cierra cuando termina el viaje.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra inferior del pasajero: pedir cupo o cancelar el suyo (regla 4).
class _RiderActionBar extends StatefulWidget {
  const _RiderActionBar({required this.ride, required this.hasSeat});

  final Ride ride;
  final bool hasSeat;

  @override
  State<_RiderActionBar> createState() => _RiderActionBarState();
}

class _RiderActionBarState extends State<_RiderActionBar> {
  bool _busy = false;

  Future<void> _cancelSeat() async {
    final rides = context.read<RidesService>();
    setState(() => _busy = true);
    try {
      await rides.cancelRequest(widget.ride.id, context.read<AuthProvider>().uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelaste tu cupo. El asiento se devuelve.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<AuthProvider>().profile;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: widget.hasSeat
            ? FilledButton.tonal(
                onPressed: _busy ? null : _cancelSeat,
                child: const Text('Cancelar mi cupo'),
              )
            : FilledButton(
                onPressed: _busy || widget.ride.isFull || profile == null
                    ? null
                    : () async {
                        final ridesProvider = context.read<RidesProvider>();
                        final ok = await ridesProvider.requestSeat(
                          rideId: widget.ride.id,
                          rider: profile,
                          seats: 1,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Solicitud enviada. El chofer te confirma.'
                                  : ridesProvider.error ?? 'No pudimos enviar la solicitud.',
                            ),
                          ),
                        );
                      },
                child: Text(
                  widget.ride.isFull ? 'Viaje lleno' : 'Pedir cupo',
                ),
              ),
      ),
    );
  }
}