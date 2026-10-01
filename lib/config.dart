class AppConfig {
  const AppConfig._();

  static const String appName = 'GunaYala Ride';
  static const String supportPhone = '+50760000000';

  /// Escudo 911 (Policia Nacional de Panama). La app no intercepta la llamada:
  /// solo abre el dialer con el numero real.
  static const String emergencyNumber = '911';

  static const int maxSeatsPerRide = 30;
  static const int chatMaxLength = 500;
  static const int otpDigits = 6;
  static const Duration otpTtl = Duration(minutes: 10);
  static const int maxUploadBytes = 5 * 1024 * 1024;
  static const String currency = r'$';

  /// Compartir viaje = texto + link de Maps. Nunca tracking vivo publico.
  static String mapsLink({required String origin, required String destination}) {
    final o = Uri.encodeComponent(origin);
    final d = Uri.encodeComponent(destination);
    return 'https://www.google.com/maps/dir/?api=1&destination=$d&travelmode=driving&origin=$o';
  }

  static String rideLink({required String rideId}) =>
      'https://www.google.com/maps/search/?api=1&query=GunaYala+Ride+cupo+$rideId';
}