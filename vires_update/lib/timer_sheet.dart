import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'alarm.dart';
import 'screens.dart';

String clock(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Opens the exercise timer (for dead hang, plank, cycling...).
/// With a target it counts down and rings at zero. Without one it is a stopwatch.
/// Returns the seconds done, or null if cancelled.
Future<int?> showExerciseTimer(BuildContext context, String title, int target) {
  return showModalBottomSheet<int>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => ExerciseTimerSheet(title: title, target: target),
  );
}

class ExerciseTimerSheet extends StatefulWidget {
  final String title;
  final int target; // seconds, 0 = stopwatch
  const ExerciseTimerSheet({super.key, required this.title, required this.target});
  @override
  State<ExerciseTimerSheet> createState() => _ExerciseTimerSheetState();
}

class _ExerciseTimerSheetState extends State<ExerciseTimerSheet> {
  Timer? _tick;
  DateTime? _startedAt;
  Duration _before = Duration.zero; // time collected before the last pause
  bool _alerted = false;

  bool get _running => _startedAt != null;
  int get _elapsed =>
      (_before + (_startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!))).inSeconds;
  bool get _counting => widget.target > 0;
  int get _shown => _counting ? max(0, widget.target - _elapsed) : _elapsed;
  bool get _finished => _counting && _elapsed >= widget.target;

  void _start() {
    if (_finished) return;
    _startedAt = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_finished && !_alerted) {
        _alerted = true;
        _before = Duration(seconds: widget.target);
        _startedAt = null;
        _tick?.cancel();
        ringAndVibrate();
      }
      setState(() {});
    });
    setState(() {});
  }

  void _pause() {
    if (_startedAt != null) {
      _before += DateTime.now().difference(_startedAt!);
      _startedAt = null;
    }
    _tick?.cancel();
    setState(() {});
  }

  void _reset() {
    stopRing();
    _tick?.cancel();
    _startedAt = null;
    _before = Duration.zero;
    _alerted = false;
    setState(() {});
  }

  void _save() {
    stopRing();
    final secs = _counting ? min(_elapsed, widget.target) : _elapsed;
    Navigator.pop(context, secs);
  }

  void _cancel() {
    stopRing();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _finished;
    const green = Color(0xFF2B8A4B);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_counting ? 'Target ${clock(widget.target)}' : 'Stopwatch', style: const TextStyle(color: greyText)),
          const SizedBox(height: 20),
          Text(
            clock(_shown),
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w700,
              color: done ? green : accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (done) const Text("Time's up", style: TextStyle(color: green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('Reset'))),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: done ? null : (_running ? _pause : _start),
                child: Text(_running ? 'Pause' : (_elapsed > 0 ? 'Resume' : 'Start')),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextButton(onPressed: _cancel, child: const Text('Cancel'))),
            Expanded(
              child: FilledButton.tonal(onPressed: _elapsed > 0 ? _save : null, child: const Text('Save set')),
            ),
          ]),
        ]),
      ),
    );
  }
}
