import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/rides_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/rides_service.dart';
import 'services/verification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFirebaseMessagingBackground();

  try {
    await bootFirebase();
  } catch (error) {
    // Sin google-services.json real la app no puede ni leer rides.
    runApp(FirebaseSetupError(error: error));
    return;
  }

  // AuthService usa RidesService para guardar el perfil en users/{uid}, asi que
  // el orden importa.
  final ridesService = RidesService();
  final authService = AuthService(ridesService: ridesService);
  final verificationService = VerificationService();
  final notificationService = NotificationService();

  runApp(
    GunaYalaApp(
      authService: authService,
      ridesService: ridesService,
      verificationService: verificationService,
      notificationService: notificationService,
    ),
  );
}

class GunaYalaApp extends StatelessWidget {
  const GunaYalaApp({
    super.key,
    required this.authService,
    required this.ridesService,
    required this.verificationService,
    required this.notificationService,
  });

  final AuthService authService;
  final RidesService ridesService;
  final VerificationService verificationService;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService: authService,
            ridesService: ridesService,
            verificationService: verificationService,
          ),
        ),
        ChangeNotifierProvider<RidesProvider>(
          create: (_) => RidesProvider(ridesService: ridesService)..start(),
        ),
        Provider<RidesService>.value(value: ridesService),
        Provider<VerificationService>.value(value: verificationService),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const AppGate(),
      ),
    );
  }
}

/// Decide que pantalla va primero: login, onboarding o el inicio.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.signedIn) return const LoginScreen();
    if (auth.needsOnboarding) return const OnboardingScreen();
    return const HomeShell();
  }
}

/// Pantalla de arranque cuando Firebase no esta configurado de verdad.
class FirebaseSetupError extends StatelessWidget {
  const FirebaseSetupError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: kCianOscuro),
                const SizedBox(height: 16),
                Text(
                  'Falta configurar Firebase',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pone tu google-services.json en android/app/ y vuelve a abrir la app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
