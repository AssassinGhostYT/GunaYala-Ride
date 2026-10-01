import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/ride_request.dart';
import '../services/rides_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'chat_screen.dart';

/// Solicitudes de cupo del viaje. El chofer acepta o rechaza; aceptar no suma
/// asientos desde el movil (lo hace onSeatAccepted en el servidor).
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      body: StreamBuilder<List<RideRequest>>(
        stream: rides.watchRequests(rideId),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <RideRequest>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Aun no te piden cupo.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _RequestTile(
              rideId: rideId,
              request: items[index],
            ),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.rideId, required this.request});

  final String rideId;
  final RideRequest request;

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kCianOscuro.withValues(alpha: 0.12),
                  child: Text(
                    initialsOf(request.riderName),
                    style: const TextStyle(color: kCianOscuro),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.riderName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${request.seats} cupo(s)  -  ${request.status.label}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (request.status == RequestStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => rides.rejectRequest(rideId, request.id),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => rides.acceptRequest(rideId, request.id),
                      child: const Text('Aceptar cupo'),
                    ),
                  ),
                ],
              ),
            ] else if (request.status == RequestStatus.accepted)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(rideId: rideId, title: request.riderName),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Abrir chat (solo en abordaje o en camino)'),
              ),
          ],
        ),
      ),
    );
  }
}