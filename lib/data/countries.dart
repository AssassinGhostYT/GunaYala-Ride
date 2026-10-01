/// Paises y su codigo telefonico. Panama es el principal: la app es de Panama,
/// pero un extranjero tambien puede entrar a buscar un carro, asi que puede
/// elegir su pais y su prefijo.
class Country {
  const Country(this.code, this.dialCode, this.name);

  /// ISO-3166 alpha-2, ejemplo PA.
  final String code;

  /// Con el signo, ejemplo +507.
  final String dialCode;

  final String name;

  /// +507 6123 4567
  String e164(String national) => '$dialCode$national';

  String get flagLabel => '+$dialCode';

  @override
  String toString() => '$name $flagLabel';
}

/// El pais por defecto. Todo arranca aqui.
const Country kPanama = Country('PA', '+507', 'Panama');

/// Digitos que espera el celular. Panama usa 8; el resto del mundo 6 a 12.
const int kPanamaCelularDigits = 8;

List<Country> countriesForSignup() {
  final all = <Country>[
    kPanama,
    // Centroamerica
    Country('CR', '+506', 'Costa Rica'),
    Country('NI', '+505', 'Nicaragua'),
    Country('SV', '+503', 'El Salvador'),
    Country('HN', '+504', 'Honduras'),
    Country('GT', '+502', 'Guatemala'),
    Country('BZ', '+501', 'Belice'),
    Country('PA', '+507', 'Panama'),
    // Caribe y norte
    Country('DO', '+1 809', 'Republica Dominicana'),
    Country('CU', '+53', 'Cuba'),
    Country('JM', '+1 876', 'Jamaica'),
    Country('PR', '+1 787', 'Puerto Rico'),
    Country('US', '+1', 'Estados Unidos'),
    Country('CA', '+1', 'Canada'),
    // Suramerica
    Country('CO', '+57', 'Colombia'),
    Country('VE', '+58', 'Venezuela'),
    Country('EC', '+593', 'Ecuador'),
    Country('PE', '+51', 'Peru'),
    Country('BR', '+55', 'Brasil'),
    Country('AR', '+54', 'Argentina'),
    Country('CL', '+56', 'Chile'),
    Country('BO', '+591', 'Bolivia'),
    Country('PY', '+595', 'Paraguay'),
    Country('UY', '+598', 'Uruguay'),
    Country('GY', '+592', 'Guyana'),
    Country('SR', '+597', 'Surinam'),
    // Sur de america
    Country('CO', '+57', 'Colombia'),
    // Europa
    Country('ES', '+34', 'España'),
    Country('FR', '+33', 'Francia'),
    Country('DE', '+49', 'Alemania'),
    Country('IT', '+39', 'Italia'),
    Country('GB', '+44', 'Reino Unido'),
    Country('NL', '+31', 'Paises Bajos'),
    Country('PT', '+351', 'Portugal'),
    Country('CH', '+41', 'Suiza'),
    Country('RU', '+7', 'Rusia'),
    Country('UA', '+380', 'Ucrania'),
    // Asia y Oceania
    Country('CN', '+86', 'China'),
    Country('JP', '+81', 'Japon'),
    Country('KR', '+82', 'Corea del Sur'),
    Country('IN', '+91', 'India'),
    Country('AU', '+61', 'Australia'),
    Country('NZ', '+64', 'Nueva Zelanda'),
  ];
  // Panama arriba de todo y sin repetir (Canada y Estados Unidos comparten +1).
  final seen = <String>{};
  final ordered = <Country>[];
  for (final country in all) {
    if (seen.add(country.code)) ordered.add(country);
  }
  return ordered;
}