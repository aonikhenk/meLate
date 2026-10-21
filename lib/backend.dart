import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Conexión con Firebase. Solo guarda un código anónimo y el token de
/// notificaciones. Sin nombres, contraseñas ni datos de wifi.
class Backend {
  static final _db = FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Inicia sesión anónima (sin contraseña) y registra el token push.
  static Future<String> init() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();

    await FirebaseMessaging.instance.requestPermission(
        alert: true, sound: true, badge: true);
    final token = await FirebaseMessaging.instance.getToken();

    final userRef = _db.collection('users').doc(uid);
    final snap = await userRef.get();
    String? code = snap.data()?['code'];
    code ??= await _claimCode();
    await userRef.set({'token': token, 'code': code}, SetOptions(merge: true));

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      userRef.set({'token': t}, SetOptions(merge: true));
    });
    return code;
  }

  /// Reserva un código de 6 caracteres único para emparejar teléfonos.
  static Future<String> _claimCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    while (true) {
      final code =
          List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
      final ref = _db.collection('codes').doc(code);
      final ok = await _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {'uid': uid});
        return true;
      });
      if (ok) return code;
    }
  }

  /// Devuelve el uid asociado a un código, o null si no existe.
  static Future<String?> uidForCode(String code) async {
    final d = await _db.collection('codes').doc(code.toUpperCase()).get();
    return d.data()?['uid'];
  }

  /// kind: 'beat' (exige respuesta), 'auto' (tomó el teléfono), 'reply'.
  /// mood: 'happy' | 'sad' | 'auto'
  static Future<void> send(String to, String kind, String mood) {
    return _db.collection('beats').add({
      'from': uid,
      'to': to,
      'kind': kind,
      'mood': mood,
      'answered': false,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  /// Todo lo recibido (latidos, respuestas y automáticos).
  static Stream<QuerySnapshot<Map<String, dynamic>>> incoming() {
    return _db.collection('beats').where('to', isEqualTo: uid).snapshots();
  }

  static Future<void> remove(String id) =>
      _db.collection('beats').doc(id).delete();

  /// Responde un latido: avisa al emisor y borra el original.
  static Future<void> answer(String beatId, String from, String mood) async {
    await _db.collection('beats').doc(beatId).update({'answered': true});
    await send(from, 'reply', mood);
    await _db.collection('beats').doc(beatId).delete();
  }
}
