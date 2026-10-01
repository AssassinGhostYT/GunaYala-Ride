import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/countries.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

/// Entrar con correo y contrasena. Crear cuenta pide correo, contrasena,
/// nombre, apellido, edad, pais y celular. Panama (+507) viene por defecto,
/// pero se puede elegir otro pais.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _edad = TextEditingController();
  final _celular = TextEditingController();

  bool _crearCuenta = false;
  bool _busy = false;
  bool _ocultar = true;
  String? _error;
  Country _pais = kPanama;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _edad.dispose();
    _celular.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      if (_crearCuenta) {
        await auth.register(
          email: _email.text,
          password: _password.text,
          nombre: _nombre.text.trim(),
          apellido: _apellido.text.trim(),
          edad: int.parse(_edad.text.trim()),
          celular: _celular.text.replaceAll(RegExp(r'\D'), ''),
          pais: _pais,
          role: auth.chosenRole,
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(error);
      });
    }
  }

  void _alternar() {
    setState(() {
      _crearCuenta = !_crearCuenta;
      _error = null;
      _busy = false;
    });
  }

  String? _validarCorreo(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu correo.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text)) {
      return 'Ese correo no parece valido.';
    }
    return null;
  }

  String? _validarContrasena(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Escribe tu contrasena.';
    if (_crearCuenta && text.length < 6) return 'Minimo 6 caracteres.';
    return null;
  }

  String? _validarNombre(String? value, String etiqueta) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu $etiqueta.';
    if (text.length < 2) return 'Tu $etiqueta es muy corto.';
    return null;
  }

  String? _validarEdad(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu edad.';
    final edad = int.tryParse(text);
    if (edad == null) return 'Solo numeros.';
    if (edad < 18) return 'Debes tener 18 anos o mas para conducir.';
    if (edad > 100) return 'Esa edad no es valida.';
    return null;
  }

  String? _validarCelular(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Escribe tu celular.';
    if (_pais.code == 'PA' && digits.length != 8) {
      return 'En Panama el celular tiene 8 digitos.';
    }
    if (digits.length < 6 || digits.length > 12) {
      return 'Revisa el numero de tu celular.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GunayalaBrand(),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entrar')),
                    ButtonSegment(value: true, label: Text('Crear cuenta')),
                  ],
                  selected: {_crearCuenta},
                  onSelectionChanged: (selection) {
                    if (selection.first != _crearCuenta) _alternar();
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _crearCuenta
                      ? 'Crea tu cuenta en un minuto'
                      : 'Entra a tu cuenta de GunaYala Ride',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _crearCuenta
                      ? 'Somos de Panama. Si vienes de otro pais, elige el tuyo para tu celular.'
                      : 'Con tu correo y contrasena.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    hintText: 'tucorreo@ejemplo.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: _validarCorreo,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _ocultar,
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                      icon: Icon(_ocultar ? Icons.visibility_off : Icons.visibility),
                      tooltip: 'Ver contrasena',
                    ),
                  ),
                  validator: _validarContrasena,
                ),
                if (_crearCuenta) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ana',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => _validarNombre(value, 'nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apellido,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      hintText: 'Perez',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => _validarNombre(value, 'apellido'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _edad,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      hintText: '34',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: _validarEdad,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Country>(
                    initialValue: _pais,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pais',
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: [
                      for (final country in countriesForSignup())
                        DropdownMenuItem(
                          value: country,
                          child: Text(
                            country.code == 'PA'
                                ? '${country.name}  ${country.dialCode}  (principal)'
                                : '${country.name}  ${country.dialCode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (country) {
                      if (country != null) setState(() => _pais = country);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _celular,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Celular',
                      hintText: _pais.code == 'PA' ? '6123 4567' : 'Tu numero',
                      prefixText: '${_pais.dialCode} ',
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                    validator: _validarCelular,
                  ),
                  const SizedBox(height: 12),
                  const RoleChoice(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _enviar,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_crearCuenta ? 'Crear mi cuenta' : 'Entrar'),
                ),
                if (!_crearCuenta) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final email = _email.text.trim();
                            if (_validarCorreo(email) != null) return;
                            try {
                              await context.read<AuthProvider>().resetPassword(email);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Te enviamos el enlace a tu correo.'),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authErrorMessage(error))),
                              );
                            }
                          },
                    child: const Text('Olvide mi contrasena'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Tu correo y tu celular solo se muestran al chofer con el que compartes cupo.',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elige si va de pasajero o de chofer. El rol se escribe una vez, en el
/// registro, y despues lo confirma el onboarding.
class RoleChoice extends StatelessWidget {
  const RoleChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().chosenRole;
    return SegmentedButton<Role>(
      segments: const [
        ButtonSegment(
          value: Role.rider,
          label: Text('Voy a pedir cupo'),
          icon: Icon(Icons.person_outline),
        ),
        ButtonSegment(
          value: Role.driver,
          label: Text('Voy a ofrecer cupo'),
          icon: Icon(Icons.directions_car),
        ),
      ],
      selected: {role},
      onSelectionChanged: (selection) =>
          context.read<AuthProvider>().setChosenRole(selection.first),
    );
  }
}

/// Icono de la app, mostrado arriba del formulario.
class GunayalaBrand extends StatelessWidget {
  const GunayalaBrand({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(height: 10),
        Text(
          AppConfig.appName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Text(
          'Guna Yala, Panama',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
      ],
    );
  }
}