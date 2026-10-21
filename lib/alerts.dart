import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Notificaciones, sonidos y vibración repetida hasta que respondan.
class Alerts {
  static final _n = FlutterLocalNotificationsPlugin();
  static final _player = AudioPlayer();
  static Timer? _vibe;
  static Timer? _soundLoop;
  static String? _ringMood;
  static int _gen = 0;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _n.initialize(const InitializationSettings(android: android, iOS: ios));
    await _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        usageType: AndroidUsageType.notificationRingtone,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
  }

  static String _file(String mood) =>
      mood == 'happy' ? 'sounds/feliz.mp3' : 'sounds/triste.mp3';

  /// Suena una sola vez (respuestas).
  static Future<void> playOnce(String mood) async {
    if (_ringMood != null) return; // no interrumpir un latido pendiente
    try {
      await _player.stop();
      await _player.play(AssetSource(_file(mood)));
    } catch (_) {}
  }

  static Future<void> showFromPush(Map<String, dynamic> d) async {
    final kind = d['kind'];
    final mood = d['mood'];
    final title = switch (kind) {
      'beat' => mood == 'happy' ? '💖 Latido feliz' : '💔 Latido triste',
      'reply' => mood == 'happy' ? '💖 Respondió feliz' : '💔 Respondió triste',
      _ => '💓 Tomó su teléfono',
    };
    await _n.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      kind == 'beat' ? 'Abre MeLate y responde' : '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'latido', 'Latidos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: false, // el sonido lo pone la app
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  /// Vibra y suena en bucle mientras haya latidos sin responder.
  static void startRinging(String mood) {
    if (_ringMood == mood) return;
    stopRinging();
    _ringMood = mood;
    final gen = ++_gen;

    _vibe = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 700, 300, 700]);
      }
    });

    Future<void> playLoop() async {
      if (_ringMood == null || gen != _gen) return;
      try {
        await _player.stop();
        await _player.play(AssetSource(_file(mood)));
      } catch (_) {}
    }

    playLoop();
    _player.onPlayerComplete.first.then((_) {
      if (gen != _gen || _ringMood == null) return;
      // Pausa de 2 s entre repeticiones.
      _soundLoop = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (_ringMood == null || gen != _gen) return t.cancel();
        if (_player.state != PlayerState.playing && t.tick % 3 == 0) {
          await playLoop();
        }
      });
    });
  }

  static void stopRinging() {
    _ringMood = null;
    _gen++;
    _vibe?.cancel();
    _vibe = null;
    _soundLoop?.cancel();
    _soundLoop = null;
    _player.stop();
    Vibration.cancel();
  }
}
