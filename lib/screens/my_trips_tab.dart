import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/ride.dart';
import '../providers/auth_provider.dart';
import '../services/rides_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'requests_screen.dart';
import 'ride_detail_screen.dart';

/// Mis viajes: los que publico como chofer y los cupos que tengo confirmados.
class MyTripsTab extends StatefulWidget {
  const MyTripsTab({super.key});

  @override
  State<MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends State<MyTripsTab> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis viajes'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: kCianClaro,
          tabs: const [Tab(text: 'Mis cupos'), Tab(text: 'Publicados')],
        ),
      ),
      body: auth.isDriver
          ? TabBarView(
              controller: _tabs,
              children: const [_MyBookings(), _DriverRides()],
            )
          : const _MyBookings(),
    );
  }
}

class _MyBookings extends StatelessWidget {
  const _MyBookings();

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    return StreamBuilder<List<Ride>>(
      stream: rides.watchMyBookings(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Ride>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const _Empty(message: 'Aun no tienes cupos confirmados.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _TripTile(ride: items[index], mine: true),
        );
      },
    );
  }
}

class _DriverRides extends StatelessWidget {
  const _DriverRides();

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    return StreamBuilder<List<Ride>>(
      stream: rides.watchDriverRides(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Ride>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const _Empty(message: 'Aun no has publicado viajes.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ride = items[index];
            return Column(
              children: [
                _TripTile(ride: ride, mine: false),
                if (ride.status == RideStatus.scheduled)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RequestsScreen(rideId: ride.id),
                      ),
                    ),
                    icon: const Icon(Icons.inbox),
                    label: Text(
                      ride.riderIds.isEmpty
                          ? 'Sin cupos vendidos'
                          : 'Solicitudes y pasajeros (${ride.riderIds.length})',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.ride, required this.mine});

  final Ride ride;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: kCianOscuro.withValues(alpha: 0.12),
          child: Text(
            initialsOf(mine ? ride.driverName : ride.destination),
            style: const TextStyle(color: kCianOscuro, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          '${ride.origin} -> ${ride.destination}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${departureLabel(ride.departureAt)}  ${dayLabel(ride.departureAt)}  '
          '${ride.status.label}  ${seatsLabel(ride.vehicleSeats, ride.seatsReserved)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ride.status == RideStatus.boarding ||
                ride.status == RideStatus.inProgress
            ? TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RideDetailScreen(rideId: ride.id),
                  ),
                ),
                child: const Text('Abrir'),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RideDetailScreen(rideId: ride.id),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: kCianClaro),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}