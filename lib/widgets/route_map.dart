import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ride.dart';

/// Centro aproximado de Guna Yala (El Porvenir).
const LatLng kGunaYala = LatLng(9.5547, -78.9472);

/// Toca el mapa para marcar un punto. Si no hay clave de Maps, el mapa sale
/// en blanco pero el link de Maps al compartir sigue funcionando.
class RouteMapPicker extends StatefulWidget {
  const RouteMapPicker({super.key, required this.onPicked});

  final void Function(double lat, double lng) onPicked;

  @override
  State<RouteMapPicker> createState() => _RouteMapPickerState();
}

class _RouteMapPickerState extends State<RouteMapPicker> {
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(target: kGunaYala, zoom: 8),
          onTap: (position) {
            setState(() => _picked = position);
            widget.onPicked(position.latitude, position.longitude);
          },
          markers: _picked == null
              ? const <Marker>{}
              : <Marker>{
                  Marker(
                    markerId: const MarkerId('origen'),
                    position: _picked!,
                  ),
                },
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

/// Mapa del viaje: salida y destino marcados.
class RouteMapView extends StatelessWidget {
  const RouteMapView({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    if (!ride.hasGps) return const SizedBox.shrink();

    final origin = LatLng(ride.originPoint!.lat, ride.originPoint!.lng);
    final destination = LatLng(ride.destinationPoint!.lat, ride.destinationPoint!.lng);

    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (origin.latitude + destination.latitude) / 2,
              (origin.longitude + destination.longitude) / 2,
            ),
            zoom: 9,
          ),
          markers: <Marker>{
            Marker(markerId: const MarkerId('salida'), position: origin),
            Marker(markerId: const MarkerId('destino'), position: destination),
          },
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}