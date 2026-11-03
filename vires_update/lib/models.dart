import 'dart:math';

enum ExType { weighted, bodyweight, bodyweightPlus, timed, cardio, carry }

const categories = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio', 'Mobility', 'Other'];

String typeLabel(ExType t) => switch (t) {
      ExType.weighted => 'Weight and reps',
      ExType.bodyweight => 'Reps',
      ExType.bodyweightPlus => 'Bodyweight plus added kg',
      ExType.carry => 'Weight and distance in metres',
      ExType.timed => 'Time in seconds',
      ExType.cardio => 'Time in minutes and distance',
    };

String newId() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';
String slug(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
double round2(double v) => (v * 100).round() / 100;
String fmtRest(int s) => s <= 0 ? 'off' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Default rest between sets (seconds), keyed by exercise id. Anything not listed gets 90 s.
const _defaultRest = {
  'pull_ups': 150, 'dips': 150, 'overhead_press': 150, 'seated_cable_row': 90, 'push_ups': 75,
  'dead_hang': 60, 'back_squat': 150, 'bulgarian_split_squat': 105, 'seated_leg_curl': 90,
  'standing_calf_raises': 75, 'dead_bug': 50, 'stationary_bike': 0, 'chin_ups': 120, 'step_ups': 90,
  'one_arm_dumbbell_row': 90, 'farmer_s_carry': 90, 'side_plank': 50, 'hip_flexor_stretch': 30,
  'ankle_rocks': 30, 'thoracic_rotations': 30, 'shoulder_wall_slides': 30, 'supported_deep_squat_hold': 30,
};
int defaultRestFor(String exerciseId) => _defaultRest[exerciseId] ?? 90;

class Exercise {
  final String id, name, category;
  final ExType type;
  double step; // kg added by the "Load" button, removed by "Deload"

  Exercise({required this.id, required this.name, required this.category, required this.type, this.step = 2.5});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category, 'type': type.name, 'step': step};

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'],
        name: j['name'],
        category: j['category'],
        type: ExType.values.byName(j['type']),
        step: (j['step'] as num).toDouble(),
      );
}

class SetLog {
  double weight; // kg (added kg for bodyweightPlus)
  int reps;
  int secs; // seconds (timed and cardio)
  double km;
  double meters; // distance for carries
  bool done;

  SetLog({this.weight = 0, this.reps = 0, this.secs = 0, this.km = 0, this.meters = 0, this.done = false});

  SetLog copy() => SetLog(weight: weight, reps: reps, secs: secs, km: km, meters: meters);

  Map<String, dynamic> toJson() => {'w': weight, 'r': reps, 's': secs, 'k': km, 'm': meters, 'd': done};

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        weight: (j['w'] as num).toDouble(),
        reps: j['r'],
        secs: j['s'],
        km: (j['k'] as num).toDouble(),
        meters: (j['m'] as num?)?.toDouble() ?? 0,
        done: j['d'],
      );
}

class SessionExercise {
  final String exerciseId;
  final List<SetLog> sets;
  int rest; // seconds between sets

  SessionExercise(this.exerciseId, this.sets, {int? rest}) : rest = rest ?? defaultRestFor(exerciseId);

  Map<String, dynamic> toJson() => {'e': exerciseId, 'sets': sets.map((s) => s.toJson()).toList(), 'rest': rest};

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        j['e'],
        (j['sets'] as List).map((s) => SetLog.fromJson(s)).toList(),
        rest: j['rest'],
      );
}

class Session {
  final String id;
  final DateTime date;
  String name;
  final List<SessionExercise> items;

  Session({required this.id, required this.date, required this.name, required this.items});

  int get totalSets => items.fold(0, (a, i) => a + i.sets.length);
  int get doneSets => items.fold(0, (a, i) => a + i.sets.where((s) => s.done).length);

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date.toIso8601String(), 'name': name, 'items': items.map((i) => i.toJson()).toList()};

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'],
        date: DateTime.parse(j['date']),
        name: j['name'],
        items: (j['items'] as List).map((i) => SessionExercise.fromJson(i)).toList(),
      );
}

class RoutineItem {
  final String exerciseId;
  int sets, reps, secs;
  double weight, meters;
  int rest; // seconds between sets

  RoutineItem(this.exerciseId, this.sets,
      {this.reps = 0, this.weight = 0, this.secs = 0, this.meters = 0, int? rest})
      : rest = rest ?? defaultRestFor(exerciseId);

  Map<String, dynamic> toJson() => {'e': exerciseId, 'sets': sets, 'r': reps, 'w': weight, 's': secs, 'm': meters, 'rest': rest};

  factory RoutineItem.fromJson(Map<String, dynamic> j) =>
      RoutineItem(j['e'], j['sets'],
          reps: j['r'],
          weight: (j['w'] as num).toDouble(),
          secs: j['s'],
          meters: (j['m'] as num?)?.toDouble() ?? 0,
          rest: j['rest']);
}

class Routine {
  final String id;
  String name;
  final List<RoutineItem> items;

  Routine({required this.id, required this.name, required this.items});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': items.map((i) => i.toJson()).toList()};

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'],
        name: j['name'],
        items: (j['items'] as List).map((i) => RoutineItem.fromJson(i)).toList(),
      );
}
