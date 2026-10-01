import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/ride.dart';
import '../services/contact_service.dart';
import '../services/rides_service.dart';
import '../theme.dart';

/// Escudo: compartir el viaje (texto + link de Maps), llamar al chofer con su
/// numero real y el 911. Sin tracking vivo publico, sin VoIP.
class ShieldScreen extends StatelessWidget {
  const ShieldScreen({super.key, this.ride});

  final Ride? ride;

  @override
  Widget build(BuildContext context) {
    final rides = context.read<RidesService>();
    final contact = ContactService(ridesService: rides);
    final ride = this.ride;

    return Scaffold(
      appBar: AppBar(title: const Text('Escudo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.shield, color: kCianOscuro),
              title: Text('Tu seguridad primero'),
              subtitle: Text(
                'Comparte el viaje con tu familia. El 911 es de la Policia Nacional.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (ride != null) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final result = await SharePlus.instance.share(
                  ShareParams(text: contact.shareText(ride)),
                );
                final ok = result.status == ShareResultStatus.success;
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Viaje compartido.' : 'No se compartio.')),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir viaje con mi familia'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await contact.callDriver(ride.driverPhone);
                if (!context.mounted || ok) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El chofer no tiene numero guardado.')),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('Llamar al chofer'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await contact.callEmergency();
              },
              icon: const Icon(Icons.local_police, color: kCoral),
              label: const Text('Llamar al ${AppConfig.emergencyNumber}'),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: () => contact.callEmergency(),
              icon: const Icon(Icons.local_police, color: kCoral),
              label: const Text('Llamar al ${AppConfig.emergencyNumber}'),
            ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lo que GunaYala Ride no hace',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('- No muestra tu ubicacion en publico.'),
                  Text('- No cobra ni procesa pagos.'),
                  Text('- No graba llamadas ni audio.'),
                  Text('- No comparte tus datos con terceros.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final url = Uri.parse('mailto:${AppConfig.supportPhone}');
              await launchUrl(url);
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('Escribir a soporte ${AppConfig.supportPhone}'),
          ),
        ],
      ),
    );
  }
}