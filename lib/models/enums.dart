enum Role {
  driver,
  rider;

  static Role parse(String? raw) =>
      Role.values.firstWhere((r) => r.name == raw, orElse: () => Role.rider);

  String get label => this == Role.driver ? 'Chofer' : 'Pasajero';
}

/// En Panama no hay API publica de licencias ni de cedulas, asi que el status
/// de verificacion solo lo escribe reviewDriverVerification (revision humana).
enum VerificationStatus {
  none,
  pending,
  approved,
  verified,
  rejected,
  expired;

  static VerificationStatus parse(String? raw) => VerificationStatus.values
      .firstWhere((s) => s.name == raw, orElse: () => VerificationStatus.none);

  bool get isVerified =>
      this == VerificationStatus.approved || this == VerificationStatus.verified;

  String get label => switch (this) {
        VerificationStatus.none => 'Sin verificar',
        VerificationStatus.pending => 'En revision',
        VerificationStatus.approved => 'Aprobada',
        VerificationStatus.verified => 'Verificada',
        VerificationStatus.rejected => 'Rechazada',
        VerificationStatus.expired => 'Vencida',
      };
}

enum RideStatus {
  scheduled,
  boarding,
  inProgress,
  completed,
  cancelled;

  static RideStatus parse(String? raw) => RideStatus.values
      .firstWhere((s) => s.name == raw, orElse: () => RideStatus.scheduled);

  String get label => switch (this) {
        RideStatus.scheduled => 'Programado',
        RideStatus.boarding => 'Abordaje',
        RideStatus.inProgress => 'En camino',
        RideStatus.completed => 'Terminado',
        RideStatus.cancelled => 'Cancelado',
      };
}

enum RequestStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  static RequestStatus parse(String? raw) => RequestStatus.values
      .firstWhere((s) => s.name == raw, orElse: () => RequestStatus.pending);

  String get label => switch (this) {
        RequestStatus.pending => 'Esperando',
        RequestStatus.accepted => 'Cupo confirmado',
        RequestStatus.rejected => 'Rechazado',
        RequestStatus.cancelled => 'Cancelado',
      };
}

/// En Guna Yala casi no hay carros: hay 4x4 y panganas.
enum VehicleKind {
  fourByFour('4x4'),
  pangana('pangana'),
  sedan('sedan'),
  busito('busito');

  const VehicleKind(this.label);

  final String label;

  static VehicleKind parse(String? raw) => VehicleKind.values
      .firstWhere((k) => k.label == raw, orElse: () => VehicleKind.pangana);

  /// Asientos fisicos por defecto segun el tipo de carro. El chofer puede
  /// ajustarlo, pero nunca puede ofrecer mas cupos que asientos.
  int get typicalSeats => switch (this) {
        VehicleKind.fourByFour => 6,
        VehicleKind.pangana => 14,
        VehicleKind.sedan => 4,
        VehicleKind.busito => 15,
      };
}

class ReportReason {
  const ReportReason._();

  /// Regla 6: estos apagan la insignia (onSafetyReport) y van a revision humana.
  static const List<String> grave = [
    'amenaza',
    'manejo_peligroso',
    'arma',
    'acoso',
  ];

  static const List<MapEntry<String, String>> all = [
    MapEntry('manejo_peligroso', 'Manejo peligroso'),
    MapEntry('amenaza', 'Amenaza o intimidacion'),
    MapEntry('arma', 'Porta un arma'),
    MapEntry('acoso', 'Acoso o discriminacion'),
    MapEntry('no_show', 'No llego al punto'),
    MapEntry('mal_trato', 'Mal trato'),
    MapEntry('otro', 'Otro'),
  ];

  static bool isGrave(String reason) => grave.contains(reason);

  static String label(String reason) {
    for (final entry in all) {
      if (entry.key == reason) return entry.value;
    }
    return reason;
  }
}