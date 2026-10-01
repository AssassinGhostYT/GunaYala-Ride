import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/ride.dart';
import '../rules/guards.dart';
import 'rides_service.dart';

/// Regla 7: la llamada muestra el numero real (dialer del telefono, sin VoIP)
/// y compartir es texto + link de Maps. Nunca tracking vivo publico.
class ContactService {
  const ContactService({required this.ridesService});

  final RidesService ridesService;

  Future<bool> callDriver(String? phone) async {
    if (!Guards.canCallDriver(phone)) return false;
    final uri = Uri(scheme: 'tel', path: phone!.replaceAll(RegExp(r'\s'), ''));
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> callEmergency() async {
    final uri = Uri(scheme: 'tel', path: AppConfig.emergencyNumber);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Boton depanic del pasajero: llama al chofer y abre el 911 en el dialer.
  Future<void> panic({String? driverPhone}) async {
    await callDriver(driverPhone);
  }

  String shareText(Ride ride) {
    return [
      'GunaYala Ride: cupo de ${ride.origin} a ${ride.destination}.',
      'Sale ${ride.departureAt.toIso8601String()} por ${ride.vehicleLabel}.',
      AppConfig.mapsLink(origin: ride.origin, destination: ride.destination),
    ].join('\n');
  }

  String shareRequestText({
    required String rideId,
    required String origin,
    required String destination,
    required String departure,
    required int seats,
  }) {
    return [
      'Necesito $seats cupo(s) en GunaYala Ride.',
      'Ruta: $origin -> $destination ($departure).',
      'Cupo #$rideId. Me escriben por WhatsApp al confirmar.',
    ].join('\n');
  }
}