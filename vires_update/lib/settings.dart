import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'alarm.dart';
import 'screens.dart';

const _channel = MethodChannel('vires/icon');

// (id used by the Android side, name, picture)
const _icons = [
  ('Shield', 'Shield of faith', 'assets/icon/icon.png'),
  ('David', 'David', 'assets/icon/david.png'),
  ('Michael', 'Archangel Michael', 'assets/icon/michael.png'),
  ('Crusader', 'Crusader', 'assets/icon/crusader.png'),
  ('Lion', 'Lion of Judah', 'assets/icon/lion.png'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String current = 'Shield';
  bool? custom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final has = await hasCustomSound();
    String? icon;
    try {
      icon = await _channel.invokeMethod<String>('get');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      custom = has;
      current = icon ?? 'Shield';
    });
  }

  void _say(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));

  Future<void> _choose(String id) async {
    try {
      await _channel.invokeMethod('set', {'name': id});
      setState(() => current = id);
      _say('Icon changed. Your home screen can take a few seconds to update.');
    } on MissingPluginException {
      _say('Changing the icon only works on the phone.');
    } catch (_) {
      _say('Could not change the icon.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('App icon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
        ),
        softCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tap an icon to use it on your home screen.', style: TextStyle(color: greyText, fontSize: 13)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
                children: [
                  for (final (id, name, path) in _icons)
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _choose(id),
                      child: Column(children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: current == id ? accent : Colors.transparent, width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(path, cacheWidth: 256, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: current == id ? FontWeight.w700 : FontWeight.w400)),
                      ]),
                    ),
                ],
              ),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('Timer sound', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
        ),
        softCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                custom == null
                    ? 'Checking...'
                    : custom!
                        ? 'Using your own Vires sound.'
                        : 'Using the phone alarm sound.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text('Rings when a rest timer or an exercise timer finishes.',
                  style: TextStyle(color: greyText, fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton.tonalIcon(
                  onPressed: ringAndVibrate,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: stopRing, child: const Text('Stop')),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
