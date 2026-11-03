import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';

// ---------------------------------------------------------------------------
// The sharing format is plain text that anyone can read and type by hand:
//
//   Monday: Upper body
//   - Pull-ups: 3 x 6, rest 2:30
//   - Overhead Press: 3 x 6 @ 30 kg, rest 2:30
//   - Dead Hang: 2 x 30 s, rest 1:00
//   - Farmer's Carry: 3 x 30 m @ 16 kg, rest 1:30
//   - Stationary Bike: 1 x 15 min, rest off
//
// First line = routine name. Then one line per exercise, starting with a dash.
// ---------------------------------------------------------------------------

String exportRoutine(Routine r) {
  final b = StringBuffer('${r.name}\n');
  for (final i in r.items) {
    final found = store.exercises.where((e) => e.id == i.exerciseId);
    if (found.isEmpty) continue;
    final e = found.first;
    final amount = switch (e.type) {
      ExType.timed => '${i.sets} x ${i.secs} s',
      ExType.cardio => '${i.sets} x ${fmt(round2(i.secs / 60))} min',
      ExType.carry => '${i.sets} x ${fmt(i.meters)} m',
      _ => '${i.sets} x ${i.reps}',
    };
    final hasWeight = e.type == ExType.weighted || e.type == ExType.bodyweightPlus || e.type == ExType.carry;
    final weight = hasWeight && i.weight > 0 ? ' @ ${fmt(i.weight)} kg' : '';
    b.writeln('- ${e.name}: $amount$weight, rest ${fmtRest(i.rest)}');
  }
  return b.toString();
}

String exportAll() => store.routines.map(exportRoutine).join('\n');

class ImportResult {
  int routines = 0;
  int newExercises = 0;
  final List<String> skipped = [];
}

final _setsRe = RegExp(r'(\d+)\s*[x×]\s*(\d+(?:[.,]\d+)?)(?:\s*-\s*(\d+(?:[.,]\d+)?))?\s*(min|sec|reps?|s|m)?\b',
    caseSensitive: false);
final _weightRe = RegExp(r'@\s*(\d+(?:[.,]\d+)?)\s*kg', caseSensitive: false);
final _restRe = RegExp(r'rest\s*:?\s*(off|none|\d+:\d{2}|\d+\s*(?:min|sec|s)?)', caseSensitive: false);

double _num(String s) => double.parse(s.replaceAll(',', '.'));

int? _parseRest(String? s) {
  if (s == null) return null;
  final t = s.toLowerCase().trim();
  if (t == 'off' || t == 'none') return 0;
  if (t.contains(':')) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
  final n = int.parse(RegExp(r'\d+').firstMatch(t)!.group(0)!);
  return t.endsWith('min') ? n * 60 : n;
}

Exercise _findOrCreate(String name, String unit, bool hasWeight, ImportResult res) {
  final i = store.exercises.indexWhere((e) => e.name.toLowerCase() == name.toLowerCase() || e.id == slug(name));
  if (i >= 0) return store.exercises[i];
  final type = switch (unit) {
    'min' => ExType.cardio,
    's' || 'sec' => ExType.timed,
    'm' => ExType.carry,
    _ => hasWeight ? ExType.weighted : ExType.bodyweight,
  };
  final e = Exercise(id: slug(name), name: name, category: 'Other', type: type);
  store.exercises.add(e);
  res.newExercises++;
  return e;
}

/// Reads the text, adds the routines to the app, and tells what happened.
ImportResult importRoutines(String text) {
  final res = ImportResult();
  final found = <Routine>[];
  Routine? current;

  for (final raw in text.replaceAll('’', "'").split('\n')) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    line = line.replaceFirst(RegExp(r'^[•*–—]'), '-');

    if (!line.startsWith('-')) {
      current = Routine(id: newId(), name: line, items: []);
      found.add(current);
      continue;
    }
    if (current == null) {
      res.skipped.add(line);
      continue;
    }
    final body = line.substring(1).trim();
    final colon = body.indexOf(':');
    if (colon < 1) {
      res.skipped.add(line);
      continue;
    }
    final name = body.substring(0, colon).trim();
    final spec = body.substring(colon + 1);
    final m = _setsRe.firstMatch(spec);
    if (m == null) {
      res.skipped.add(line);
      continue;
    }
    final sets = min(20, max(1, int.parse(m.group(1)!)));
    final v = _num(m.group(3) ?? m.group(2)!); // for a range like 6-8 we take the top
    final unit = (m.group(4) ?? '').toLowerCase();
    final w = _weightRe.firstMatch(spec);
    final weight = w == null ? 0.0 : _num(w.group(1)!);
    final rest = _parseRest(_restRe.firstMatch(spec)?.group(1));
    final ex = _findOrCreate(name, unit, weight > 0, res);

    current.items.add(switch (ex.type) {
      ExType.timed => RoutineItem(ex.id, sets, secs: (unit == 'min' ? v * 60 : v).round(), rest: rest),
      ExType.cardio => RoutineItem(ex.id, sets, secs: (unit == 's' || unit == 'sec' ? v : v * 60).round(), rest: rest),
      ExType.carry => RoutineItem(ex.id, sets, meters: v, weight: weight, rest: rest),
      ExType.weighted || ExType.bodyweightPlus => RoutineItem(ex.id, sets, reps: v.round(), weight: weight, rest: rest),
      ExType.bodyweight => RoutineItem(ex.id, sets, reps: v.round(), rest: rest),
    });
  }

  for (final r in found) {
    if (r.items.isEmpty) continue;
    store.routines.add(r);
    res.routines++;
  }
  store.save();
  return res;
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

Future<void> showExportDialog(BuildContext context, String title, String text) {
  final messenger = ScaffoldMessenger.of(context);
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Copy this text and send it in any chat app. Your friend taps Import and pastes it.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
              child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) Navigator.pop(ctx);
            messenger.showSnackBar(const SnackBar(content: Text('Copied. Now paste it in a message.')));
          },
        ),
      ],
    ),
  );
}

Future<void> showImportDialog(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = TextEditingController();
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import a routine'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste the text of a routine, then tap Import.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Monday: Upper body\n- Pull-ups: 3 x 6, rest 2:30\n- Dips: 3 x 8, rest 2:30',
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Paste from clipboard'),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) ctrl.text = d!.text!;
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'How to write one by hand: first line is the name. Then one line per exercise starting with a dash. '
              'Write sets x reps. Add @ 30 kg for weight, "s" for seconds, "min" for minutes, "m" for metres. '
              'Add rest 1:30 for the rest between sets.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.4),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final r = importRoutines(ctrl.text);
            Navigator.pop(ctx);
            if (r.routines == 0) {
              messenger.showSnackBar(const SnackBar(
                content: Text('I could not find a routine in that text. Each exercise line must start with a dash.'),
              ));
              return;
            }
            var msg = 'Imported ${r.routines} ${r.routines == 1 ? 'routine' : 'routines'}.';
            if (r.newExercises > 0) msg += ' ${r.newExercises} new exercises added under Other.';
            if (r.skipped.isNotEmpty) msg += ' Skipped ${r.skipped.length} line(s) I could not read: ${r.skipped.first}';
            messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
          },
          child: const Text('Import'),
        ),
      ],
    ),
  );
}
