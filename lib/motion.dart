import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detecta que el teléfono fue tomado (movimiento tras estar quieto).
class Motion {
  static StreamSubscription? _sub;
  static DateTime _lastMove = DateTime.now();
  static const _minGap = Duration(hours: 2); // máximo 1 latido auto cada 2 h

  static void start({required void Function() onPickup}) {
    _sub = accelerometerEventStream().listen((e) {
      final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final moving = (g - 9.81).abs() > 1.5;
      if (moving) {
        // Si estuvo quieto más de 5 min y ahora se mueve: lo tomó.
        if (DateTime.now().difference(_lastMove) > const Duration(minutes: 5)) {
          onPickup();
        }
        _lastMove = DateTime.now();
      }
    });
  }

  static void stop() => _sub?.cancel();

  static Future<bool> canSendAuto() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getInt('lastAuto') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _minGap.inMilliseconds) return false;
    await p.setInt('lastAuto', now);
    return true;
  }
}
