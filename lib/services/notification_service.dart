import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'auth_service.dart';

/// Push: el token se guarda hasheado en users/{uid}/devices/{hash}.
class NotificationService {
  NotificationService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  Future<void> registerDevice() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } on FirebaseException {
      // Sin permiso de notificaciones la app sigue funcionando.
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    final hash = AuthService.deviceHash(token);
    await _db.doc('users/$uid/devices/$hash').set({
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _messaging.onTokenRefresh.listen((fresh) async {
      final freshHash = AuthService.deviceHash(fresh);
      await _db.doc('users/$uid/devices/$freshHash').set({
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Mensaje en primer plano: los avisos llegan como data, no como notificacion
  /// automatica, para que la app decida que mostrar.
  Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;
}

@pragma('vm:entry-point')
Future<void> _backgroundHandlerTop(RemoteMessage message) async {
  // Notificaciones de GunaYala Ride: el contenido llega en data.
}

void registerFirebaseMessagingBackground() {
  FirebaseMessaging.onBackgroundMessage(_backgroundHandlerTop);
}