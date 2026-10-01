import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../services/verification_service.dart';
import '../theme.dart';

/// Verificacion. En Panama no hay API publica de licencias ni de cedulas:
/// el cliente sube fotos y una persona revisa. El status nunca se escribe
/// desde el movil.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final verification = auth.driverVerification;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificacion de chofer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        verification.status.isVerified
                            ? Icons.verified
                            : Icons.verified_outlined,
                        color: verification.status.isVerified ? kCianOscuro : Colors.black38,
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Insignia: ${verification.status.label}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            verification.badgeActive
                                ? 'Puedes publicar viajes'
                                : 'No puedes publicar viajes',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (verification.badgeSuspended) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kCoral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gpp_maybe, color: kCoral),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Insignia apagada por un reporte grave '
                              '(${ReportReason.label(verification.badgeSuspendedReason)}). '
                              'Pasa a revision humana.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (verification.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Nota de la revision: ${verification.note}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Documentos (opcional, ayuda a que te aprueben mas rapido)'),
          const SizedBox(height: 8),
          const Text(
            'Cedula, licencia y foto del carro. Maximo 4 fotos de 5 MB cada una. '
            'Solo tu y el personal de revision ven estos archivos.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final service = context.read<VerificationService>();
              try {
                await service.uploadDocuments(folder: 'driver');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fotos subidas. Ahora pide la revision.')),
                );
              } on VerificationException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.message)));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No pudimos subir las fotos.')),
                );
              }
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Subir documentos'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: verification.status == VerificationStatus.pending
                ? null
                : () async {
                    final service = context.read<VerificationService>();
                    await service.requestDriverReview();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pedimos la revision. Te avisamos por WhatsApp.'),
                      ),
                    );
                  },
            icon: const Icon(Icons.how_to_reg),
            label: Text(
              verification.status == VerificationStatus.pending
                  ? 'Revision en proceso'
                  : 'Pedir revision de documentos',
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: kCianOscuro),
              title: Text('Por que revision humana?'),
              subtitle: Text(
                'En Panama no hay API publica de licencias ni de cedulas, asi que '
                'la insignia no se puede verificar solo.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}