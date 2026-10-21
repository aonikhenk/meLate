import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend.dart';
import 'theme.dart';

/// Contactos guardados SOLO en el teléfono (apodo + código anónimo).
class Contact {
  final String nick, code, uid;
  Contact(this.nick, this.code, this.uid);
  Map<String, String> toJson() => {'nick': nick, 'code': code, 'uid': uid};
  factory Contact.fromJson(Map<String, dynamic> j) =>
      Contact(j['nick'], j['code'], j['uid']);
}

class Contacts {
  static const max = 9; // 9 contactos + el propio usuario = 10 en total

  static Future<List<Contact>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('contacts') ?? [];
    return raw.map((s) => Contact.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> save(List<Contact> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'contacts', list.map((c) => jsonEncode(c.toJson())).toList());
  }

  static Future<String> nameFor(String uid) async {
    for (final c in await load()) {
      if (c.uid == uid) return c.nick;
    }
    return 'Alguien';
  }
}

class ContactsPage extends StatefulWidget {
  final String? myCode;
  const ContactsPage({super.key, this.myCode});
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> _list = [];
  final _nick = TextEditingController();
  final _code = TextEditingController();
  String _msg = '';

  @override
  void initState() {
    super.initState();
    Contacts.load().then((l) => setState(() => _list = l));
  }

  Future<void> _add() async {
    if (_list.length >= Contacts.max) {
      setState(() => _msg = 'Máximo ${Contacts.max} contactos');
      return;
    }
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _msg = 'El código tiene 6 letras');
      return;
    }
    if (code == widget.myCode) {
      setState(() => _msg = 'Ese es tu propio código');
      return;
    }
    try {
      final uid = await Backend.uidForCode(code);
      if (uid == null) {
        setState(() => _msg = 'Código no encontrado');
        return;
      }
      _list.removeWhere((c) => c.code == code);
      _list.add(Contact(
          _nick.text.trim().isEmpty ? code : _nick.text.trim(), code, uid));
      await Contacts.save(_list);
      _nick.clear();
      _code.clear();
      FocusScope.of(context).unfocus();
      setState(() => _msg = 'Agregado ✔');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 18, color: MeColors.soft);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi familia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MeColors.coral,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                const Text('Mi código',
                    style: TextStyle(fontSize: 20, color: Colors.white70)),
                const SizedBox(height: 6),
                SelectableText(widget.myCode ?? '······',
                    style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Compártelo con tu familia',
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Agregar a alguien', style: label),
          const SizedBox(height: 10),
          TextField(
              controller: _nick,
              style: const TextStyle(fontSize: 22),
              decoration:
                  const InputDecoration(labelText: 'Nombre (ej: Mamá, Hijo)')),
          const SizedBox(height: 12),
          TextField(
              controller: _code,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Su código', counterText: '')),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: MeColors.ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22))),
              onPressed: _add,
              child: const Text('Agregar', style: TextStyle(fontSize: 22)),
            ),
          ),
          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: MeColors.ink)),
            ),
          const SizedBox(height: 28),
          Text('Mi familia (${_list.length}/${Contacts.max})', style: label),
          const SizedBox(height: 10),
          if (_list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aún no agregas a nadie',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: MeColors.soft)),
            ),
          ..._list.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: MeColors.coral.withValues(alpha: 0.15),
                      child: Text(c.nick.characters.first.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: MeColors.coral)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nick,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w600)),
                          Text(c.code,
                              style: const TextStyle(
                                  fontSize: 15, color: MeColors.soft)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 28, color: MeColors.soft),
                      onPressed: () async {
                        _list.remove(c);
                        await Contacts.save(_list);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
