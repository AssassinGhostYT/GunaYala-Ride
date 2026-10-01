import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/ride_request.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/contact_service.dart';
import '../services/rides_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'reviews_screen.dart';

/// Ficha de confianza del chofer: insignia, viajes dados, resenas, contacto,
/// reportar y bloquear.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.driverId,
    required this.name,
    required this.phone,
    required this.verified,
  });

  final String driverId;
  final String name;
  final String phone;
  final bool verified;

  Future<void> _report(BuildContext context) async {
    final rides = context.read<RidesService>();
    final auth = context.read<AuthProvider>();

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Por que lo reportas?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final entry in ReportReason.all)
              ListTile(
                title: Text(entry.value),
                subtitle: ReportReason.isGrave(entry.key)
                    ? const Text('Apaga la insignia de inmediato')
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Un reporte grave apaga la insignia de una vez. El chofer no puede ver '
                'quien lo reporto.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    await rides.report(
      SafetyReport(
        reportedId: driverId,
        reporterId: auth.uid,
        reason: reason,
        reportedRole: Role.driver,
      ),
      reporterName: auth.profile?.name ?? '',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte enviado. Gracias por avisar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    final contact = ContactService(ridesService: rides);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: kCianOscuro.withValues(alpha: 0.12),
                  child: Text(
                    initialsOf(name),
                    style: const TextStyle(
                      color: kCianOscuro,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Tooltip(
                              message: 'Insignia verificada por revision humana',
                              child: Icon(Icons.verified, size: 18, color: kCianOscuro),
                            ),
                          ],
                        ],
                      ),
                      FutureBuilder<UserProfile?>(
                        future: rides.fetchProfile(driverId),
                        builder: (context, snapshot) {
                          final profile = snapshot.data;
                          final average = profile?.ratingAverage;
                          return Text(
                            average == null
                                ? 'Sin resenas todavia'
                                : '${average.toStringAsFixed(1)} de 5 (${profile!.ratingCount} resenas)',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await contact.callDriver(phone);
                      if (!context.mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Este chofer no tiene numero guardado.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReviewsScreen(driverId: driverId, name: name),
                      ),
                    ),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Resenas'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _report(context),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Reportar'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await rides.block(driverId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bloqueado. No te va a escribir.')),
                    );
                  },
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Bloquear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}