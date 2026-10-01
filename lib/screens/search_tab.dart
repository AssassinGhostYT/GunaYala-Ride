import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../widgets/ride_card.dart';
import 'ride_detail_screen.dart';

/// Pestana Buscar: filtro por cupos disponibles. Un viaje lleno no sale.
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RidesProvider>();
    final auth = context.watch<AuthProvider>();
    final visible = rides.visibleRides;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: 'Solo con cupo',
            onPressed: () => rides.setOnlyWithSeats(!rides.onlyWithSeats),
            icon: Icon(
              rides.onlyWithSeats ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => rides.start(),
        child: rides.loading
            ? const Center(child: CircularProgressIndicator())
            : visible.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      _EmptySearch(),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ride = visible[index];
                      return RideCard(
                        ride: ride,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RideDetailScreen(rideId: ride.id),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: auth.isDriver
          ? FloatingActionButton.extended(
              onPressed: auth.canPublish
                  ? null
                  : () => _showBadgeNotice(context),
              icon: const Icon(Icons.publish),
              label: const Text('Publicar'),
            )
          : null,
    );
  }

  void _showBadgeNotice(BuildContext context) {
    final status = context.read<AuthProvider>().driverVerification.status.label;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Para publicar necesitas la insignia verificada. Ahora: $status.'),
        action: SnackBarAction(
          label: 'Entendido',
          onPressed: () {},
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.route, size: 72, color: kCianClaro),
        const SizedBox(height: 16),
        const Text(
          'Aun no hay viajes con cupo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Aqui aparecen los viajes que los choferes publican para Guna Yala. '
            'El pago se hace directo con el chofer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Publica tu nombre y tu numero real. El pago es directo con el chofer.',
          style: TextStyle(color: Colors.black38, fontSize: 12),
        ),
      ],
    );
  }
}