import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Los datos (correo, nombre, apellido, edad, celular) ya se piden al
/// registrarse. Aqui solo queda el rol y, si es chofer, el carro.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();

  late Role _role;
  VehicleKind _kind = VehicleKind.pangana;
  int _seats = VehicleKind.pangana.typicalSeats;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = context.read<AuthProvider>().chosenRole;
    _seats = _kind.typicalSeats;
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().completeOnboarding(
            role: _role,
            vehicleKind: _role == Role.driver ? _kind : null,
            plate: _role == Role.driver ? _plate.text : null,
            seats: _role == Role.driver ? _seats : null,
          );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos guardar tus datos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Un paso mas')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Como vas a usar GunaYala Ride?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<Role>(
                segments: const [
                  ButtonSegment(
                    value: Role.rider,
                    label: Text('Pasajero'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment(
                    value: Role.driver,
                    label: Text('Chofer'),
                    icon: Icon(Icons.directions_car),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (value) => setState(() {
                  _role = value.first;
                  _seats = _kind.typicalSeats;
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _role == Role.driver
                    ? 'Registra tu carro y podras pedir la verificacion de chofer.'
                    : 'Ya casi. Asi te contactamos cuando aceptes un cupo.',
                style: const TextStyle(color: Colors.black54),
              ),
              if (_role == Role.driver) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_car, color: kCianOscuro),
                            const SizedBox(width: 8),
                            Text(
                              'Tu carro',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<VehicleKind>(
                          key: ValueKey(_kind),
                          initialValue: _kind,
                          decoration: const InputDecoration(labelText: 'Tipo de carro'),
                          items: VehicleKind.values
                              .map(
                                (kind) => DropdownMenuItem(
                                  value: kind,
                                  child: Text('${kind.label} (~${kind.typicalSeats} asientos)'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            _kind = value ?? _kind;
                            _seats = _kind.typicalSeats;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _plate,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Placa o identificacion',
                            hintText: 'Sino tiene placa, pon SIN PLACA',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Asientos fisicos: $_seats', style: Theme.of(context).textTheme.titleSmall),
                        Slider(
                          value: _seats.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '$_seats',
                          onChanged: (value) => setState(() => _seats = value.round()),
                        ),
                        const Text(
                          'Esto es el tope de cupos. Nunca podras ofrecer mas cupos que asientos.',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar a GunaYala Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}