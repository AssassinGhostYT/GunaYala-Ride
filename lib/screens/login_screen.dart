import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Login por WhatsApp: sin contrasena. La Function manda el codigo de 6
/// digitos y devuelve un custom token.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _auth = AuthService();

  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _error;
  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendIn = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _resendIn -= 1;
        if (_resendIn <= 0) timer.cancel();
      });
    });
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) return '+507$digits';
    return '+$digits';
  }

  Future<void> _sendCode() async {
    final phone = _normalizedPhone();
    if (phone.length < 9) {
      setState(() => _error = 'Escribe tu celular de 8 digitos.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sending = false;
      });
      _startResendTimer();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _friendlyMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'No pudimos mandar el codigo. Revisa tu conexion.';
      });
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != AppConfig.otpDigits) {
      setState(() => _error = 'El codigo son ${AppConfig.otpDigits} digitos.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _auth.verifyOtp(phone: _normalizedPhone(), code: code);
      if (!mounted) return;
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _friendlyMessage(error);
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'No pudimos validar el codigo.';
      });
    }
  }

  String _friendlyMessage(Object error) {
    final message = error is FirebaseFunctionsException ? (error.message ?? '') : '';
    if (message.contains('Demasiados')) return message;
    if (message.contains('vencio')) return 'El codigo vencio. Pide uno nuevo.';
    if (message.contains('bloqueado')) return 'Codigo bloqueado. Pide uno nuevo.';
    if (message.contains('incorrecto')) return 'Codigo incorrecto.';
    return 'No pudimos validar el codigo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Brand(),
              const SizedBox(height: 28),
              Text(
                _codeSent ? 'Escribe tu codigo' : 'Tu celular, tu llave',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Te mandamos un codigo de ${AppConfig.otpDigits} digitos por WhatsApp a ${_normalizedPhone()}.'
                    : 'Te enviamos un codigo por WhatsApp. Sin contrasena, sin correos.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (!_codeSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Celular (8 digitos)',
                    hintText: '6000 0000',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  onSubmitted: (_) => _sendCode(),
                )
              else
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: AppConfig.otpDigits,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 8),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Codigo de verificacion',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending || _verifying
                    ? null
                    : _codeSent
                        ? _verify
                        : _sendCode,
                child: _sending || _verifying
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Entrar' : 'Mandar codigo'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _resendIn > 0 ? null : _sendCode,
                  child: Text(
                    _resendIn > 0 ? 'Reenviar en ${_resendIn}s' : 'Reenviar codigo',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Al entrar aceptas que tu numero de WhatsApp sea visible para los choferes con los que compartes cupo.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: kCianOscuro,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.directions_car, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Text('Guna Yala, Panama', style: TextStyle(color: Colors.black45)),
          ],
        ),
      ],
    );
  }
}