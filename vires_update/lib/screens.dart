import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models.dart';
import 'alarm.dart';
import 'progress.dart';
import 'settings.dart';
import 'share.dart';
import 'timer_sheet.dart';
import 'store.dart';

const accent = Color(0xFF3B5BDB);
const accentSoft = Color(0xFFE3E8FF);
const lineColor = Color(0xFFE8EAEE);
const greyText = Color(0xFF6B7280);

Widget softCard({required Widget child, EdgeInsets margin = const EdgeInsets.only(bottom: 12)}) => Card(
      elevation: 0,
      color: Colors.white,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lineColor),
      ),
      child: child,
    );

Future<bool> confirm(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
}

/// Opens the "start from a routine or empty" sheet, then the session.
Future<void> startSession(BuildContext context, DateTime date, {Routine? routine}) async {
  var choice = routine?.id;
  if (choice == null) {
    choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Start from', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Empty session'),
            onTap: () => Navigator.pop(ctx, 'empty'),
          ),
          for (final r in store.routines)
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(r.name),
              subtitle: Text('${r.items.length} exercises'),
              onTap: () => Navigator.pop(ctx, r.id),
            ),
        ]),
      ),
    );
  }
  if (choice == null || !context.mounted) return;
  final d = DateTime(date.year, date.month, date.day);
  final session = choice == 'empty'
      ? Session(id: newId(), date: d, name: 'Workout', items: [])
      : store.sessionFromRoutine(store.routines.firstWhere((r) => r.id == choice), d);
  store.addSession(session);
  Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(session: session)));
}

// ===========================================================================
// Home with bottom navigation
// ===========================================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [CalendarScreen(), ProgressScreen(), RoutinesScreen(), ExercisesScreen()];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.show_chart), selectedIcon: Icon(Icons.insights), label: 'Progress'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Routines'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Exercises'),
        ],
      ),
    );
  }
}

// ===========================================================================
// Calendar
// ===========================================================================
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime focused = DateTime.now();
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final day = store.sessionsOn(selected);
        return Scaffold(
          appBar: AppBar(title: const Text('Vires'), actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => startSession(context, selected),
            icon: const Icon(Icons.add),
            label: const Text('Add session'),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            softCard(
              child: TableCalendar<Session>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 1, 1),
                focusedDay: focused,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
                selectedDayPredicate: (d) => isSameDay(d, selected),
                eventLoader: (d) => store.sessionsOn(d),
                onDaySelected: (s, f) => setState(() {
                  selected = s;
                  focused = f;
                }),
                onPageChanged: (f) => focused = f,
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: accentSoft, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
                  selectedDecoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  markersMaxCount: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (day.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No session on this day. Tap Add session to plan one.', style: TextStyle(color: greyText)),
              ),
            for (final s in day)
              softCard(
                child: ListTile(
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.items.length} exercises, ${s.doneSets} of ${s.totalSets} sets done'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirm(context, 'Delete this session?')) store.deleteSession(s);
                    },
                  ),
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(session: s))),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ===========================================================================
// Session: log sets, load / deload
// ===========================================================================
class SessionScreen extends StatefulWidget {
  final Session session;
  const SessionScreen({super.key, required this.session});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int version = 0; // bumps when weights change from a button, so the fields refresh
  Session get s => widget.session;

  // ---- rest timer (counts down to a fixed end time, so it stays correct if the app pauses) ----
  Timer? _timer;
  DateTime? _restEnd;
  String _restName = '';
  bool _restDone = false;

  int get _remaining {
    if (_restEnd == null) return 0;
    final ms = _restEnd!.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  void startRest(int secs, String name) {
    _timer?.cancel();
    _restEnd = DateTime.now().add(Duration(seconds: secs));
    _restName = name;
    _restDone = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == 0 && !_restDone) {
        _restDone = true;
        ringAndVibrate();
      }
      setState(() {});
    });
    setState(() {});
  }

  void stopRest() {
    stopRing();
    _timer?.cancel();
    _timer = null;
    _restEnd = null;
    setState(() {});
  }

  void adjustRest(int delta) {
    if (_restEnd == null) return;
    stopRing();
    final now = DateTime.now();
    final base = _restEnd!.isAfter(now) ? _restEnd! : now;
    _restEnd = base.add(Duration(seconds: delta));
    _restDone = false;
    setState(() {});
  }

  @override
  void dispose() {
    stopRing();
    _timer?.cancel();
    super.dispose();
  }

  Widget? _restBar() {
    if (_restEnd == null) return null;
    final left = _remaining;
    final done = left == 0;
    const green = Color(0xFF2B8A4B);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFE6F6EC) : accentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(done ? 'Rest over' : 'Rest ${fmtRest(left)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: done ? green : accent)),
              Text(_restName, style: const TextStyle(color: greyText, fontSize: 12)),
            ]),
          ),
          TextButton(onPressed: () => adjustRest(-15), child: const Text('-15 s')),
          TextButton(onPressed: () => adjustRest(15), child: const Text('+15 s')),
          IconButton(tooltip: 'Close', onPressed: stopRest, icon: const Icon(Icons.close)),
        ]),
      ),
    );
  }

  bool _hasWeight(Exercise e) =>
      e.type == ExType.weighted || e.type == ExType.bodyweightPlus || e.type == ExType.carry;

  /// sign = +1 to load, -1 to deload. Changes one set (setIndex) or every set of the exercise.
  void shift(SessionExercise it, int sign, {int? setIndex}) {
    final e = store.ex(it.exerciseId);
    for (var i = 0; i < it.sets.length; i++) {
      if (setIndex != null && i != setIndex) continue;
      it.sets[i].weight = round2(max(0, it.sets[i].weight + sign * e.step));
    }
    version++;
    store.save();
    setState(() {});
  }

  /// Ticks every set (of one exercise, or the whole session). If all are already ticked, unticks them.
  void tickAll({SessionExercise? only}) {
    final sets = [
      for (final it in s.items)
        if (only == null || it == only) ...it.sets,
    ];
    final target = !sets.every((l) => l.done);
    for (final l in sets) {
      l.done = target;
    }
    store.save();
    setState(() {});
  }

  Future<void> addExercise() async {
    final e = await Navigator.push<Exercise>(
        context, MaterialPageRoute(builder: (_) => const ExercisesScreen(picking: true)));
    if (e == null) return;
    s.items.add(SessionExercise(e.id, [SetLog(weight: store.lastWeight(e.id, s.date))]));
    store.save();
    setState(() {});
  }

  Future<void> saveRoutine() async {
    final ctrl = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as routine'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    store.addRoutine(Routine(id: newId(), name: name, items: [
      for (final it in s.items)
        RoutineItem(it.exerciseId, it.sets.length,
            reps: it.sets.isEmpty ? 0 : it.sets.first.reps,
            weight: it.sets.isEmpty ? 0 : it.sets.first.weight,
            secs: it.sets.isEmpty ? 0 : it.sets.first.secs,
            meters: it.sets.isEmpty ? 0 : it.sets.first.meters,
            rest: it.rest),
    ]));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine saved')));
  }

  Widget exerciseCard(SessionExercise it) {
    final e = store.ex(it.exerciseId);
    final pr = store.isPR(s, it);
    return softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(e.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            if (pr)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFF1CC), borderRadius: BorderRadius.circular(8)),
                child: const Text('PR', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A6100))),
              ),
            if (_hasWeight(e)) ...[
              IconButton(
                tooltip: 'Deload all sets -${fmt(e.step)} kg',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.trending_down),
                onPressed: () => shift(it, -1),
              ),
              IconButton(
                tooltip: 'Load all sets +${fmt(e.step)} kg',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.trending_up),
                onPressed: () => shift(it, 1),
              ),
            ],
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'tick') tickAll(only: it);
                if (v == 'remove') {
                  s.items.remove(it);
                  store.save();
                  setState(() {});
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'tick', child: Text('Tick or untick all sets')),
                PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
              ],
            ),
          ]),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, children: [
            Text(typeLabel(e.type), style: const TextStyle(color: greyText, fontSize: 13)),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final v = await pickRest(context, e.name, it.rest);
                if (v != null) {
                  it.rest = v;
                  store.save();
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, size: 16, color: accent),
                  const SizedBox(width: 4),
                  Text('Rest ${fmtRest(it.rest)}',
                      style: const TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < it.sets.length; i++)
            SetRow(
              key: ValueKey('${it.exerciseId}-$i-$version-${it.sets.length}'),
              index: i,
              type: e.type,
              set: it.sets[i],
              step: e.step,
              onTimer: (e.type == ExType.timed || e.type == ExType.cardio)
                  ? () async {
                      final st = it.sets[i];
                      final secs = await showExerciseTimer(context, e.name, st.secs);
                      if (secs == null) return;
                      st.secs = secs;
                      st.done = true;
                      version++; // refresh the fields with the new time
                      store.save();
                      setState(() {});
                      if (it.rest > 0 && it.sets.any((l) => !l.done)) startRest(it.rest, e.name);
                    }
                  : null,
              onTicked: () {
                final more = it.sets.any((l) => !l.done); // rest only between sets
                if (it.rest > 0 && more) startRest(it.rest, e.name);
              },
              onShift: _hasWeight(e) ? (sign) => shift(it, sign, setIndex: i) : null,
              onChanged: () {
                store.save();
                setState(() {});
              },
              onDelete: () {
                it.sets.removeAt(i);
                store.save();
                setState(() {});
              },
            ),
          TextButton.icon(
            onPressed: () {
              it.sets.add(it.sets.isEmpty ? SetLog() : it.sets.last.copy());
              store.save();
              setState(() {});
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add set'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _restBar(),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text('${s.date.day}/${s.date.month}/${s.date.year}',
              style: const TextStyle(fontSize: 12, color: greyText, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Tick or untick all sets',
            icon: const Icon(Icons.done_all),
            onPressed: () => tickAll(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'routine') saveRoutine();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'routine', child: Text('Save as routine'))],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        if (s.items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Tap a set number to load or deload that set. Tick sets as you finish them.',
                style: TextStyle(color: greyText, fontSize: 13)),
          ),
        if (s.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('This session is empty. Add your first exercise.', style: TextStyle(color: greyText)),
          ),
        for (final it in s.items) exerciseCard(it),
        FilledButton.tonalIcon(
          onPressed: addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ]),
    );
  }
}

/// One row of inputs. The fields shown depend on the exercise type.
class SetRow extends StatefulWidget {
  final int index;
  final ExType type;
  final SetLog set;
  final VoidCallback onChanged, onDelete;
  final double step;
  final void Function(int sign)? onShift; // null when the exercise has no weight
  final VoidCallback? onTicked; // called when the set gets ticked
  final Future<void> Function()? onTimer; // opens the exercise timer (timed and cardio sets)
  const SetRow(
      {super.key,
      required this.index,
      required this.type,
      required this.set,
      required this.step,
      this.onShift,
      this.onTicked,
      this.onTimer,
      required this.onChanged,
      required this.onDelete});
  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final Map<String, TextEditingController> c;

  String _txt(double v) => v == 0 ? '' : fmt(v);

  @override
  void initState() {
    super.initState();
    final st = widget.set;
    final timeVal = widget.type == ExType.cardio ? st.secs / 60 : st.secs.toDouble();
    c = {
      'w': TextEditingController(text: _txt(st.weight)),
      'r': TextEditingController(text: _txt(st.reps.toDouble())),
      't': TextEditingController(text: _txt(round2(timeVal))),
      'k': TextEditingController(text: _txt(st.km)),
      'm': TextEditingController(text: _txt(st.meters)),
    };
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String unit, void Function(double) apply) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: c[key],
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: unit,
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onChanged: (v) {
            apply(double.tryParse(v.replaceAll(',', '.')) ?? 0);
            widget.onChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.set;
    final fields = switch (widget.type) {
      ExType.weighted => [
          _field('w', 'kg', (v) => st.weight = v),
          _field('r', 'reps', (v) => st.reps = v.round()),
        ],
      ExType.bodyweightPlus => [
          _field('w', '+kg', (v) => st.weight = v),
          _field('r', 'reps', (v) => st.reps = v.round()),
        ],
      ExType.bodyweight => [_field('r', 'reps', (v) => st.reps = v.round())],
      ExType.carry => [
          _field('w', 'kg', (v) => st.weight = v),
          _field('m', 'm', (v) => st.meters = v),
        ],
      ExType.timed => [_field('t', 'sec', (v) => st.secs = v.round())],
      ExType.cardio => [
          _field('t', 'min', (v) => st.secs = (v * 60).round()),
          _field('k', 'km', (v) => st.km = v),
        ],
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        PopupMenuButton<String>(
          tooltip: 'Set options',
          padding: EdgeInsets.zero,
          onSelected: (v) {
            if (v == 'up') widget.onShift?.call(1);
            if (v == 'down') widget.onShift?.call(-1);
            if (v == 'delete') widget.onDelete();
          },
          itemBuilder: (_) => [
            if (widget.onShift != null) PopupMenuItem(value: 'up', child: Text('Load this set +${fmt(widget.step)} kg')),
            if (widget.onShift != null)
              PopupMenuItem(value: 'down', child: Text('Deload this set -${fmt(widget.step)} kg')),
            const PopupMenuItem(value: 'delete', child: Text('Delete set')),
          ],
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 4),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: accentSoft, shape: BoxShape.circle),
            child: Text('${widget.index + 1}',
                style: const TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        ...fields,
        if (widget.onTimer != null)
          IconButton(
            tooltip: 'Start timer',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.play_circle_outline, color: accent),
            onPressed: widget.onTimer,
          ),
        Checkbox(
          value: st.done,
          onChanged: (v) {
            st.done = v ?? false;
            widget.onChanged();
            if (st.done) widget.onTicked?.call();
          },
        ),
      ]),
    );
  }
}

// ===========================================================================
// Routines
// ===========================================================================
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineEditorScreen(routine: Routine(id: newId(), name: '', items: []), isNew: true),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('New routine'),
        ),
        appBar: AppBar(title: const Text('Routines'), actions: [
          IconButton(
            tooltip: 'Import a routine',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => showImportDialog(context),
          ),
          IconButton(
            tooltip: 'Share all routines',
            icon: const Icon(Icons.ios_share),
            onPressed: () => showExportDialog(context, 'Share all routines', exportAll()),
          ),
        ]),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
          if (store.routines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No routines yet. Tap New routine, or import one with the button at the top.',
                  style: TextStyle(color: greyText)),
            ),
          for (final r in store.routines)
            softCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirm(context, 'Delete routine "${r.name}"?')) store.deleteRoutine(r);
                      },
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Text(
                      r.items.map((i) => '${store.ex(i.exerciseId).name} x${i.sets}').join(', '),
                      style: const TextStyle(color: greyText, fontSize: 13),
                    ),
                  ),
                  Wrap(alignment: WrapAlignment.end, children: [
                    TextButton.icon(
                      onPressed: () => showExportDialog(context, r.name, exportRoutine(r)),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: r, isNew: false))),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => startSession(context, DateTime.now(), routine: r),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start today'),
                    ),
                  ]),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Exercise library (also used as a picker)
// ===========================================================================
class ExercisesScreen extends StatefulWidget {
  final bool picking;
  const ExercisesScreen({super.key, this.picking = false});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String query = '';

  Future<void> addCustom() async {
    final name = TextEditingController();
    var cat = categories.first;
    var type = ExType.weighted;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New exercise'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: cat,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final x in categories) DropdownMenuItem(value: x, child: Text(x))],
              onChanged: (v) => setD(() => cat = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExType>(
              value: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final x in ExType.values) DropdownMenuItem(value: x, child: Text(typeLabel(x)))],
              onChanged: (v) => setD(() => type = v!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    store.addExercise(Exercise(id: newId(), name: name.text.trim(), category: cat, type: type));
  }

  Future<void> editStep(Exercise e) async {
    final ctrl = TextEditingController(text: fmt(e.step));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.name),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Load / deload step', suffixText: 'kg', helperText: 'Used by the Load and Deload buttons'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (ok == true && v != null && v > 0) {
      e.step = v;
      store.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.toLowerCase();
        final children = <Widget>[];
        for (final cat in categories) {
          final list = store.exercises.where((e) => e.category == cat && e.name.toLowerCase().contains(q)).toList();
          if (list.isEmpty) continue;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(cat, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
          ));
          for (final e in list) {
            children.add(softCard(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(typeLabel(e.type)),
                trailing: widget.picking ? null : Text('step ${fmt(e.step)} kg', style: const TextStyle(color: greyText)),
                onTap: () => widget.picking ? Navigator.pop(context, e) : editStep(e),
              ),
            ));
          }
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.picking ? 'Pick an exercise' : 'Exercises')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: addCustom,
            icon: const Icon(Icons.add),
            label: const Text('New exercise'),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            ...children,
          ]),
        );
      },
    );
  }
}

// ===========================================================================
// Rest time editing
// ===========================================================================
Future<int?> pickRest(BuildContext context, String title, int current) {
  final ctrl = TextEditingController(text: '$current');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Rest between sets', suffixText: 'seconds', helperText: '0 turns the rest timer off'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final v in [45, 60, 90, 120, 150, 180])
            ActionChip(label: Text(fmtRest(v)), onPressed: () => ctrl.text = '$v'),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? current),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Create a new routine, or edit an existing one.
class RoutineEditorScreen extends StatefulWidget {
  final Routine routine;
  final bool isNew;
  const RoutineEditorScreen({super.key, required this.routine, required this.isNew});
  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final TextEditingController name = TextEditingController(text: widget.routine.name);
  Routine get r => widget.routine;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  // an existing routine saves every change straight away; a new one waits for Save
  void _changed() {
    if (!widget.isNew) store.save();
    setState(() {});
  }

  String _detail(RoutineItem i) {
    final parts = ['${i.sets} sets'];
    if (i.reps > 0) parts.add('${i.reps} reps');
    if (i.meters > 0) parts.add('${fmt(i.meters)} m');
    if (i.secs > 0) parts.add(i.secs >= 120 ? '${fmt(round2(i.secs / 60))} min' : '${i.secs} s');
    if (i.weight > 0) parts.add('${fmt(i.weight)} kg');
    parts.add('rest ${fmtRest(i.rest)}');
    return parts.join(', ');
  }

  RoutineItem _defaultItem(Exercise e) => switch (e.type) {
        ExType.timed => RoutineItem(e.id, 3, secs: 30),
        ExType.cardio => RoutineItem(e.id, 1, secs: 20 * 60),
        ExType.carry => RoutineItem(e.id, 3, meters: 30, weight: store.lastWeight(e.id, DateTime.now())),
        ExType.bodyweight => RoutineItem(e.id, 3, reps: 10),
        _ => RoutineItem(e.id, 3, reps: 8, weight: store.lastWeight(e.id, DateTime.now())),
      };

  Future<void> addExercise() async {
    final e = await Navigator.push<Exercise>(
        context, MaterialPageRoute(builder: (_) => const ExercisesScreen(picking: true)));
    if (e == null) return;
    r.items.add(_defaultItem(e));
    _changed();
  }

  Future<void> editItem(RoutineItem i) async {
    final e = store.ex(i.exerciseId);
    String txt(num v) => v == 0 ? '' : fmt(v.toDouble());
    final sets = TextEditingController(text: '${i.sets}');
    final reps = TextEditingController(text: txt(i.reps));
    final weight = TextEditingController(text: txt(i.weight));
    final time = TextEditingController(text: e.type == ExType.cardio ? txt(round2(i.secs / 60)) : txt(i.secs));
    final meters = TextEditingController(text: txt(i.meters));
    final rest = TextEditingController(text: '${i.rest}');
    Widget f(TextEditingController c, String label, String unit) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: unit),
          ),
        );
    final t = e.type;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.name),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            f(sets, 'Sets', ''),
            if (t == ExType.weighted || t == ExType.bodyweightPlus || t == ExType.bodyweight) f(reps, 'Reps', ''),
            if (t == ExType.weighted || t == ExType.bodyweightPlus || t == ExType.carry) f(weight, 'Weight', 'kg'),
            if (t == ExType.carry) f(meters, 'Distance', 'm'),
            if (t == ExType.timed) f(time, 'Time', 'seconds'),
            if (t == ExType.cardio) f(time, 'Time', 'minutes'),
            f(rest, 'Rest between sets', 'seconds'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    double n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
    i.sets = max(1, n(sets).round());
    i.reps = n(reps).round();
    i.weight = n(weight);
    i.meters = n(meters);
    i.secs = t == ExType.cardio ? (n(time) * 60).round() : n(time).round();
    i.rest = max(0, n(rest).round());
    _changed();
  }

  void save() {
    if (r.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one exercise first.')));
      return;
    }
    final n = name.text.trim();
    r.name = n.isEmpty ? 'New routine' : n;
    if (widget.isNew) {
      store.addRoutine(r);
    } else {
      store.save();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New routine' : 'Edit routine'),
        actions: [TextButton(onPressed: save, child: Text(widget.isNew ? 'Save' : 'Done'))],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: 'Routine name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                if (!widget.isNew && v.trim().isNotEmpty) {
                  r.name = v.trim();
                  store.save();
                }
              },
            ),
            const SizedBox(height: 8),
            const Text('Tap an exercise to change its sets, reps, weight and rest. Press and hold to move it.',
                style: TextStyle(color: greyText, fontSize: 13)),
          ]),
        ),
        footer: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.tonalIcon(
            onPressed: addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        ),
        onReorder: (o, n) {
          if (n > o) n -= 1;
          final it = r.items.removeAt(o);
          r.items.insert(n, it);
          _changed();
        },
        children: [
          for (final i in r.items)
            Container(
              key: ObjectKey(i),
              child: softCard(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(store.ex(i.exerciseId).name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_detail(i)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      r.items.remove(i);
                      _changed();
                    },
                  ),
                  onTap: () => editItem(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
