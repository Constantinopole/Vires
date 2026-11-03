import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

final store = Store();

// ---------------------------------------------------------------------------
// Exercise library: (name, category, type). Add or edit lines freely.
// ---------------------------------------------------------------------------
const _w = ExType.weighted, _b = ExType.bodyweight, _p = ExType.bodyweightPlus;
const _t = ExType.timed, _c = ExType.cardio, _k = ExType.carry;

const _library = <(String, String, ExType)>[
  // Chest
  ('Bench Press', 'Chest', _w), ('Incline Bench Press', 'Chest', _w), ('Dumbbell Bench Press', 'Chest', _w),
  ('Incline Dumbbell Press', 'Chest', _w), ('Chest Press Machine', 'Chest', _w), ('Chest Fly', 'Chest', _w),
  ('Cable Crossover', 'Chest', _w), ('Push-ups', 'Chest', _b), ('Dips', 'Chest', _p),
  // Back
  ('Pull-ups', 'Back', _p), ('Chin-ups', 'Back', _p), ('Lat Pulldown', 'Back', _w),
  ('Seated Cable Row', 'Back', _w), ('Barbell Row', 'Back', _w), ('One-Arm Dumbbell Row', 'Back', _w),
  ('T-Bar Row', 'Back', _w), ('Deadlift', 'Back', _w), ('Face Pull', 'Back', _w),
  ('Back Extension', 'Back', _b), ('Dead Hang', 'Back', _t),
  // Shoulders
  ('Overhead Press', 'Shoulders', _w), ('Dumbbell Shoulder Press', 'Shoulders', _w), ('Arnold Press', 'Shoulders', _w),
  ('Lateral Raise', 'Shoulders', _w), ('Front Raise', 'Shoulders', _w), ('Rear Delt Fly', 'Shoulders', _w),
  ('Shrugs', 'Shoulders', _w), ('Upright Row', 'Shoulders', _w), ('Shoulder Wall Slides', 'Shoulders', _b),
  // Arms
  ('Barbell Curl', 'Arms', _w), ('Dumbbell Curl', 'Arms', _w), ('Hammer Curl', 'Arms', _w),
  ('Preacher Curl', 'Arms', _w), ('Triceps Pushdown', 'Arms', _w), ('Skull Crusher', 'Arms', _w),
  ('Overhead Triceps Extension', 'Arms', _w), ('Close-Grip Bench Press', 'Arms', _w), ('Bench Dips', 'Arms', _b),
  // Legs
  ('Back Squat', 'Legs', _w), ('Front Squat', 'Legs', _w), ('Goblet Squat', 'Legs', _w), ('Leg Press', 'Legs', _w),
  ('Bulgarian Split Squat', 'Legs', _p), ('Lunges', 'Legs', _p), ('Step-ups', 'Legs', _p),
  ('Romanian Deadlift', 'Legs', _w), ('Hip Thrust', 'Legs', _w), ('Seated Leg Curl', 'Legs', _w),
  ('Lying Leg Curl', 'Legs', _w), ('Leg Extension', 'Legs', _w), ('Standing Calf Raises', 'Legs', _p),
  ('Seated Calf Raise', 'Legs', _w), ("Farmer's Carry", 'Legs', _k),
  // Core
  ('Plank', 'Core', _t), ('Side Plank', 'Core', _t), ('Dead Bug', 'Core', _b), ('Crunches', 'Core', _b),
  ('Hanging Leg Raise', 'Core', _b), ('Cable Crunch', 'Core', _w), ('Russian Twist', 'Core', _p),
  ('Ab Wheel Rollout', 'Core', _b), ('Bird Dog', 'Core', _b),
  // Cardio
  ('Stationary Bike', 'Cardio', _c), ('Elliptical', 'Cardio', _c), ('Incline Treadmill Walk', 'Cardio', _c),
  ('Treadmill Run', 'Cardio', _c), ('Rowing Machine', 'Cardio', _c), ('Swimming', 'Cardio', _c),
  ('Cycling Outdoors', 'Cardio', _c), ('Brisk Walking', 'Cardio', _c), ('Jump Rope', 'Cardio', _c),
  // Mobility
  ('Ankle Rocks', 'Mobility', _b), ('Hip Flexor Stretch', 'Mobility', _t), ('Thoracic Rotations', 'Mobility', _b),
  ('Supported Deep Squat Hold', 'Mobility', _t),
];

const _bigStep = {'Back Squat', 'Front Squat', 'Deadlift', 'Leg Press', 'Hip Thrust', 'Romanian Deadlift'};
const _smallStep = {
  'Lateral Raise', 'Front Raise', 'Rear Delt Fly', 'Dumbbell Curl', 'Hammer Curl',
  'Preacher Curl', 'Face Pull', 'Overhead Triceps Extension', 'Triceps Pushdown',
};

List<Exercise> _seedExercises() => [
      for (final (name, cat, type) in _library)
        Exercise(
          id: slug(name),
          name: name,
          category: cat,
          type: type,
          step: _bigStep.contains(name) ? 5 : (_smallStep.contains(name) ? 1.25 : 2.5),
        ),
    ];

// ---------------------------------------------------------------------------
// Your program (Monday, Tuesday, Thursday, Friday) as ready-made routines.
// RoutineItem(exercise, sets, reps:, weight: kg, secs: seconds)
// ---------------------------------------------------------------------------
RoutineItem _r(String name, int sets,
        {int reps = 0, double weight = 0, int secs = 0, double meters = 0, int? rest}) =>
    RoutineItem(slug(name), sets, reps: reps, weight: weight, secs: secs, meters: meters, rest: rest);

List<Routine> _seedRoutines() => [
      Routine(id: 'mon', name: 'Monday: Upper body', items: [
        _r('Pull-ups', 3, reps: 6),
        _r('Dips', 3, reps: 8),
        _r('Overhead Press', 3, reps: 6, weight: 30),
        _r('Seated Cable Row', 2, reps: 10, weight: 35),
        _r('Push-ups', 2, reps: 15),
        _r('Dead Hang', 2, secs: 30),
      ]),
      Routine(id: 'tue', name: 'Tuesday: Lower body', items: [
        _r('Back Squat', 3, reps: 5, weight: 60),
        _r('Bulgarian Split Squat', 2, reps: 6),
        _r('Seated Leg Curl', 2, reps: 10),
        _r('Standing Calf Raises', 2, reps: 12),
        _r('Dead Bug', 2, reps: 8),
        _r('Stationary Bike', 1, secs: 15 * 60),
      ]),
      Routine(id: 'thu', name: 'Thursday: Athleticism', items: [
        _r('Chin-ups', 3, reps: 6),
        _r('Dips', 2, reps: 10, rest: 90),
        _r('Step-ups', 2, reps: 8),
        _r('One-Arm Dumbbell Row', 2, reps: 10, weight: 12),
        _r("Farmer's Carry", 3, meters: 30, weight: 16),
        _r('Side Plank', 2, secs: 30),
      ]),
      Routine(id: 'fri', name: 'Friday: Cardio and mobility', items: [
        _r('Stationary Bike', 1, secs: 30 * 60),
        _r('Ankle Rocks', 2, reps: 10),
        _r('Hip Flexor Stretch', 2, secs: 30),
        _r('Thoracic Rotations', 2, reps: 8),
        _r('Shoulder Wall Slides', 2, reps: 10),
        _r('Supported Deep Squat Hold', 2, secs: 20),
      ]),
    ];

class Store extends ChangeNotifier {
  List<Exercise> exercises = [];
  List<Routine> routines = [];
  List<Session> sessions = [];
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('data');
    if (raw == null) {
      exercises = _seedExercises();
      routines = _seedRoutines();
      _prefs.setInt('seedVersion', 2);
      save();
      return;
    }
    final j = jsonDecode(raw);
    exercises = (j['exercises'] as List).map((e) => Exercise.fromJson(e)).toList();
    routines = (j['routines'] as List).map((e) => Routine.fromJson(e)).toList();
    sessions = (j['sessions'] as List).map((e) => Session.fromJson(e)).toList();
    if ((_prefs.getInt('seedVersion') ?? 1) < 2) {
      _migrateV2();
      _prefs.setInt('seedVersion', 2);
      save();
    }
  }

  /// Version 2: Farmer's Carry becomes weight + distance, and the four program
  /// routines use the top of each range.
  void _migrateV2() {
    final i = exercises.indexWhere((e) => e.id == 'farmer_s_carry');
    if (i >= 0 && exercises[i].type != ExType.carry) {
      final old = exercises[i];
      exercises[i] = Exercise(id: old.id, name: old.name, category: old.category, type: ExType.carry, step: old.step);
    }
    // sets that already have metres typed into the reps field
    for (final s in sessions) {
      for (final it in s.items) {
        if (it.exerciseId != 'farmer_s_carry') continue;
        for (final l in it.sets) {
          if (l.meters == 0 && l.reps > 0) {
            l.meters = l.reps.toDouble();
            l.reps = 0;
          }
        }
      }
    }
    const programIds = {'mon', 'tue', 'thu', 'fri'};
    routines.removeWhere((r) => programIds.contains(r.id));
    routines.insertAll(0, _seedRoutines());
  }

  void save() {
    _prefs.setString(
      'data',
      jsonEncode({
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'routines': routines.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  Exercise ex(String id) => exercises.firstWhere((e) => e.id == id);

  List<Session> sessionsOn(DateTime d) => sessions.where((s) => sameDay(s.date, d)).toList();

  void addSession(Session s) {
    sessions.add(s);
    save();
  }

  void deleteSession(Session s) {
    sessions.remove(s);
    save();
  }

  void addRoutine(Routine r) {
    routines.add(r);
    save();
  }

  void deleteRoutine(Routine r) {
    routines.remove(r);
    save();
  }

  void addExercise(Exercise e) {
    exercises.add(e);
    save();
  }

  /// Heaviest weight of the most recent earlier session where this exercise was done.
  double lastWeight(String exId, DateTime before) {
    Session? best;
    for (final o in sessions) {
      if (!o.date.isBefore(before)) continue;
      final did = o.items.any((i) => i.exerciseId == exId && i.sets.any((l) => l.done));
      if (!did) continue;
      if (best == null || o.date.isAfter(best.date)) best = o;
    }
    if (best == null) return 0;
    var w = 0.0;
    for (final i in best.items) {
      if (i.exerciseId != exId) continue;
      for (final l in i.sets) {
        if (l.done && l.weight > w) w = l.weight;
      }
    }
    return w;
  }

  /// Every session where this exercise has ticked sets, oldest first.
  List<(DateTime, List<SetLog>)> history(String exId) {
    final out = <(DateTime, List<SetLog>)>[];
    for (final s in sessions) {
      final sets = [
        for (final i in s.items)
          if (i.exerciseId == exId)
            for (final l in i.sets)
              if (l.done) l,
      ];
      if (sets.isNotEmpty) out.add((s.date, sets));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  Session sessionFromRoutine(Routine r, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return Session(id: newId(), date: d, name: r.name, items: [
      for (final it in r.items)
        SessionExercise(it.exerciseId, [
          for (var i = 0; i < it.sets; i++)
            SetLog(
              weight: lastWeight(it.exerciseId, d) > 0 ? lastWeight(it.exerciseId, d) : it.weight,
              reps: it.reps,
              secs: it.secs,
              meters: it.meters,
            ),
        ], rest: it.rest),
    ]);
  }

  /// True if a finished set in this exercise beats everything done before.
  bool isPR(Session s, SessionExercise it) {
    final type = ex(it.exerciseId).type;
    double val(SetLog l) => switch (type) {
          ExType.weighted || ExType.bodyweightPlus || ExType.carry => l.weight,
          ExType.bodyweight => l.reps.toDouble(),
          ExType.timed => l.secs.toDouble(),
          ExType.cardio => l.km,
        };
    var best = 0.0;
    for (final o in sessions) {
      if (o == s || o.date.isAfter(s.date)) continue;
      for (final i in o.items) {
        if (i.exerciseId != it.exerciseId) continue;
        for (final l in i.sets) {
          if (l.done && val(l) > best) best = val(l);
        }
      }
    }
    return it.sets.any((l) => l.done && val(l) > best && val(l) > 0);
  }
}
