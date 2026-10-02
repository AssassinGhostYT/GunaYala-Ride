import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../models/enums.dart';
import '../models/vehicle.dart';

/// Verificacion del chofer: el cliente sube fotos, una persona las revisa.
/// En Panama no hay API publica de licencias ni de cedulas, asi que el status
/// nunca se escribe desde el movil.
class VerificationService {
  VerificationService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<DriverVerification> watchDriverVerification() {
    return _db
        .doc('users/$_uid/verification/driver')
        .snapshots()
        .map((snap) => DriverVerification.fromDoc(snap.data()));
  }

  Stream<VerificationStatus> watchRiderVerification() {
    return _db
        .doc('users/$_uid/verification/rider')
        .snapshots()
        .map((snap) => VerificationStatus.parse(snap.data()?['status'] as String?));
  }

  /// El movil NO escribe el status: las reglas lo bloquean y con razón. Llama a
  /// la Function, que valida que las fotos sean tuyas y pone "pending".
  Future<void> requestDriverReview({required List<String> documentos, String nota = ''}) async {
    if (documentos.isEmpty) {
      throw const VerificationException('Sube tus fotos primero.');
    }
    try {
      await _functions.httpsCallable('requestDriverReview').call({
        'documentos': documentos,
        'nota': nota,
      });
    } on FirebaseFunctionsException catch (error) {
      throw VerificationException(
        error.message ?? 'No pudimos pedir la revision. Intenta de nuevo.',
      );
    }
  }

  /// Ruta de la Function: solo staff. Si no eres staff, permission-denied.
  Future<void> reviewAsStaff({
    required String uid,
    required VerificationStatus status,
    String note = '',
  }) async {
    await _functions.httpsCallable('reviewDriverVerification').call({
      'uid': uid,
      'status': status.name,
      'note': note,
    });
  }

  /// Documentos de verificacion: privados, los ven el dueno y el staff.
  /// Devuelve la lista de rutas ya subidas.
  Future<List<String>> uploadDocuments({required String folder, int maxFiles = 4}) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (picked.isEmpty) {
      throw const VerificationException('No elegiste ninguna foto.');
    }
    if (picked.length > maxFiles) {
      throw VerificationException('Maximo $maxFiles fotos.');
    }

    final urls = <String>[];
    for (final image in picked) {
      final bytes = await image.readAsBytes();
      if (bytes.length > AppConfig.maxUploadBytes) {
        throw const VerificationException('Cada foto puede pesar hasta 5 MB.');
      }
      final path =
          'users/$_uid/verification/$folder/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await ref.getDownloadURL());
    }

    // Las rutas se devuelven para que requestDriverReview las mande a la
    // Function. Aqui no se escribe nada en Firestore: el cliente tiene
    // prohibido tocar users/{uid}/verification.
    return urls;
  }

  /// Foto de perfil: publica.
  Future<String> uploadProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1024);
    if (picked == null) {
      throw const VerificationException('No elegiste ninguna foto.');
    }
    final bytes = await picked.readAsBytes();
    if (bytes.length > AppConfig.maxUploadBytes) {
      throw const VerificationException('La foto no puede pesar mas de 5 MB.');
    }

    final path = 'users/$_uid/profile-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    await _db.doc('users/$_uid').update({'photoUrl': url});
    return url;
  }
}

class VerificationException implements Exception {
  const VerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}