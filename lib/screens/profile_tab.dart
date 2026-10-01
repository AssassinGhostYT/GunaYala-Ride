import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../services/verification_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'shield_screen.dart';
import 'verification_screen.dart';

/// Perfil: insignia, verificacion, datos del carro, escudo y salir.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: kCianOscuro.withValues(alpha: 0.12),
                child: Text(
                  initialsOf(profile?.name ?? '?'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kCianOscuro,
                  ),
                ),
              ),
              title: Text(
                profile?.name ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${profile?.role.label ?? ''}  ${profile?.phone ?? ''}',
              ),
              trailing: profile?.photoUrl == null
                  ? IconButton(
                      tooltip: 'Foto de perfil',
                      icon: const Icon(Icons.add_a_photo_outlined),
                      onPressed: () async {
                        final service = context.read<VerificationService>();
                        try {
                          await service.uploadProfilePhoto();
                        } on VerificationException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error.message)));
                        }
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (profile != null)
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: profile.isDriver ? profile.ridesGiven : profile.ridesTaken,
                    label: profile.isDriver ? 'viajes dados' : 'cupos taken',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: profile.ratingCount,
                    label: profile.ratingAverage == null
                        ? 'resenas'
                        : '${profile.ratingAverage!.toStringAsFixed(1)} de 5',
                  ),
                ),
              ],
            ),
          if (auth.isDriver) ...[
            const SizedBox(height: 20),
            _BadgeCard(verification: auth.driverVerification),
            const SizedBox(height: 12),
            if (auth.vehicle != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: kCianOscuro),
                  title: Text(auth.vehicle!.display),
                  subtitle: Text(
                    '${auth.vehicle!.kind.label}  -  ${auth.vehicle!.seats} asientos',
                  ),
                ),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: kMango),
                  title: Text('Sin carro registrado'),
                  subtitle: Text('Registra tu carro para poder recibir solicitudes.'),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const VerificationScreen()),
              ),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verificacion de chofer'),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: kCianOscuro),
                title: Text('Pasajero'),
                subtitle: Text(
                  'Pides cupo, pagas directo al chofer y la app no te cobra nada.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShieldScreen()),
            ),
            icon: const Icon(Icons.shield),
            label: const Text('Escudo 911'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Salir de GunaYala Ride?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await context.read<AuthProvider>().signOut();
            },
            icon: const Icon(Icons.logout, color: kCoral),
            label: const Text('Salir'),
          ),
          const SizedBox(height: 16),
          const Text(
            'GunaYala Ride 1.0.0  -  cupos, no trayecto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.verification});

  final DriverVerification verification;

  @override
  Widget build(BuildContext context) {
    final active = verification.status.isVerified && verification.badgeActive;
    return Card(
      child: ListTile(
        leading: Icon(
          active ? Icons.verified : Icons.verified_outlined,
          color: active ? kCianOscuro : Colors.black38,
          size: 30,
        ),
        title: Text(
          active ? 'Insignia de chofer verificado' : 'Insignia: ${verification.status.label}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          verification.badgeSuspended
              ? 'Apagada por reporte grave. Va a revision humana.'
              : active
                  ? 'Puedes publicar viajes'
                  : 'Sin insignia no publicas viajes.',
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}