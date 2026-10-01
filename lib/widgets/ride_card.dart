import 'package:flutter/material.dart';

import '../models/ride.dart';
import '../theme.dart';
import '../utils/formatters.dart';

/// Tarjeta de viaje: ruta, hora, chofer verificado, precio y estado de cupos.
/// Los viajes llenos no llegan aqui.
class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: kCianOscuro),
                  const SizedBox(width: 6),
                  Text(
                    '${departureLabel(ride.departureAt)}  ${dayLabel(ride.departureAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  SeatsChip(ride: ride),
                ],
              ),
              const SizedBox(height: 12),
              _RouteRow(
                icon: Icons.trip_origin,
                label: ride.origin,
                color: kCianOscuro,
              ),
              const SizedBox(height: 6),
              _RouteRow(
                icon: Icons.place,
                label: ride.destination,
                color: kCoral,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  VerifiedBadge(verified: ride.driverVerified),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    ride.vehicleLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    money(ride.price),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kCianOscuro,
                    ),
                  ),
                  const Text(' por cupo', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.black26),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                paymentNotice,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class SeatsChip extends StatelessWidget {
  const SeatsChip({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final left = ride.seatsLeft;
    final color = left == 0
        ? Colors.grey
        : left == 1
            ? kMango
            : kCianOscuro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        seatsLabel(ride.vehicleSeats, ride.seatsReserved),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Regla 1: la insignia de chofer verificado. Se apaga sola con un reporte
/// grave (onSafetyReport), por eso el servidor manda el estado.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    if (!verified) return const SizedBox.shrink();
    return const Tooltip(
      message: 'Chofer verificado por revision humana',
      child: Icon(Icons.verified, size: 18, color: kCianOscuro),
    );
  }
}