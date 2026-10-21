import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'backend.dart';
import 'contacts.dart';
import 'alerts.dart';
import 'motion.dart';
import 'theme.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
  await Alerts.init();
  await Alerts.showFromPush(m.data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  await Alerts.init();
  runApp(const MeLateApp());
}

class MeLateApp extends StatelessWidget {
  const MeLateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MeLate',
        debugShowCheckedModeBanner: false,
        theme: melateTheme(),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String? _myCode;
  String _status = '';
  bool _statusIsError = false;
  bool _sending = false;
  StreamSubscription? _sub;
  List<_Pending> _pending = [];
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _start();
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = msg;
      _statusIsError = error;
    });
  }

  /// Botones de volumen: subir = feliz, bajar = triste (solo con latido pendiente).
  bool _onKey(KeyEvent e) {
    if (_pending.isEmpty) return false;
    final k = e.logicalKey;
    final isUp = k == LogicalKeyboardKey.audioVolumeUp;
    final isDown = k == LogicalKeyboardKey.audioVolumeDown;
    if (!isUp && !isDown) return false;
    if (e is KeyDownEvent) _tap(isUp ? 'happy' : 'sad');
    return true; // no cambia el volumen mientras responde
  }

  Future<void> _start() async {
    try {
      final code = await Backend.init();
      setState(() => _myCode = code);
    } catch (e) {
      _say('No pude conectar:\n$e', error: true);
      return;
    }

    _sub = Backend.incoming().listen((snap) async {
      // Primero (sin esperas) el estado de latidos pendientes, para que un
      // aviso antiguo no vuelva a activar la vibración tras responder.
      _pending = snap.docs
          .where((d) => d['kind'] == 'beat' && d['answered'] != true)
          .map((d) => _Pending(d.id, d['from'], d['mood']))
          .toList();
      _pending.isNotEmpty
          ? Alerts.startRinging(_pending.last.mood)
          : Alerts.stopRinging();
      if (mounted) setState(() {});

      for (final ch in snap.docChanges) {
        if (ch.type != DocumentChangeType.added) continue;
        final d = ch.doc.data();
        if (d == null) continue;
        final t = d['kind'];
        if (t == 'reply' || t == 'auto') {
          try {
            await Backend.remove(ch.doc.id);
          } catch (_) {}
          await Alerts.showFromPush({'kind': t, 'mood': d['mood']});
          if (t == 'reply') Alerts.playOnce(d['mood']);
          final name = await Contacts.nameFor(d['from'] ?? '');
          _say(t == 'auto'
              ? '$name tomó su teléfono 💓'
              : '$name respondió ${d['mood'] == 'happy' ? 'feliz 💖' : 'triste 💔'}');
        }
      }
    }, onError: (e) => _say('Error al recibir:\n$e', error: true));

    Motion.start(onPickup: _autoBeat);
    _autoBeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _autoBeat();
  }

  Future<void> _autoBeat() async {
    final list = await Contacts.load();
    if (list.isEmpty || !await Motion.canSendAuto()) return;
    for (final c in list) {
      try {
        await Backend.send(c.uid, 'auto', 'auto');
      } catch (_) {}
    }
  }

  Future<void> _tap(String mood) async {
    if (_sending) return;
    HapticFeedback.heavyImpact();
    setState(() => _sending = true);
    try {
      if (_pending.isNotEmpty) {
        final toAnswer = List.of(_pending);
        _pending = [];
        Alerts.stopRinging(); // al responder: silencio inmediato
        for (final p in toAnswer) {
          await Backend.answer(p.id, p.from, mood);
        }
        _say('Respondiste ${mood == 'happy' ? 'feliz 💖' : 'triste 💔'}');
        return;
      }
      final list = await Contacts.load();
      if (list.isEmpty) {
        _say('Primero agrega a tu familia en ⚙️', error: true);
        return;
      }
      for (final c in list) {
        // Se vuelve a buscar el código por si el otro reinstaló la app.
        final uid = await Backend.uidForCode(c.code)
                .timeout(const Duration(seconds: 15)) ??
            c.uid;
        await Backend.send(uid, 'beat', mood)
            .timeout(const Duration(seconds: 15));
      }
      Alerts.playOnce(mood);
      _say('Latido enviado ${mood == 'happy' ? '💖' : '💔'}');
    } on TimeoutException {
      _say('Sin respuesta del servidor. Revisa tu internet.', error: true);
    } catch (e) {
      _say('No se pudo enviar:\n$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _sub?.cancel();
    _pulse.dispose();
    Motion.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _pending.isNotEmpty;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: waiting
                ? [const Color(0xFFFFE1DC), MeColors.cream]
                : [MeColors.cream, const Color(0xFFFFEDE3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('MeLate',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    _RoundIcon(
                      icon: Icons.people_alt_rounded,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ContactsPage(myCode: _myCode))),
                    ),
                  ],
                ),
                const Spacer(),
                FutureBuilder(
                  future: waiting
                      ? Contacts.nameFor(_pending.first.from)
                      : Future.value(''),
                  builder: (_, s) => Text(
                    waiting
                        ? '${s.data ?? 'Alguien'} te envió\nun latido ${_pending.first.mood == 'happy' ? '💖' : '💔'}'
                        : '¿Cómo te sientes\nhoy?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 32),
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.06).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MeColors.coral.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        size: 110, color: MeColors.coral),
                  ),
                ),
                const Spacer(),
                _MoodButton(
                  label: waiting ? 'Estoy bien' : 'Me siento bien',
                  emoji: '💖',
                  color: MeColors.coral,
                  busy: _sending,
                  onTap: () => _tap('happy'),
                ),
                const SizedBox(height: 16),
                _MoodButton(
                  label: waiting ? 'No tan bien' : 'Me siento triste',
                  emoji: '💔',
                  color: MeColors.plum,
                  busy: _sending,
                  onTap: () => _tap('sad'),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _status.isEmpty ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _statusIsError
                          ? const Color(0xFFFFE4E0)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _statusIsError ? 16 : 20,
                        color: _statusIsError
                            ? const Color(0xFFB3261E)
                            : MeColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pending {
  final String id, from, mood;
  _Pending(this.id, this.from, this.mood);
}

class _MoodButton extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final bool busy;
  final VoidCallback onTap;
  const _MoodButton(
      {required this.label,
      required this.emoji,
      required this.color,
      required this.busy,
      required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 84,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.5),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Text(label,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.people_alt_rounded,
                size: 30, color: MeColors.ink),
          ),
        ),
      );
}
