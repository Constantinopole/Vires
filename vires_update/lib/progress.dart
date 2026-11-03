import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'screens.dart';
import 'store.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _small = TextStyle(fontSize: 11, color: greyText);

enum Agg { max, min, sum }

enum Grouping { session, week, month }

/// One thing you can chart for an exercise (max weight, volume, pace...).
class Metric {
  final String label, unit;
  final Agg agg; // how several sessions in one week/month are combined
  final double? Function(List<SetLog>) value; // value of one session from its ticked sets
  Metric(this.label, this.unit, this.agg, this.value);
}

double? _best(List<SetLog> sets, double Function(SetLog) f, {bool lowest = false}) {
  double? r;
  for (final l in sets) {
    final v = f(l);
    if (v <= 0) continue;
    if (r == null || (lowest ? v < r : v > r)) r = v;
  }
  return r;
}

double? _total(List<SetLog> sets, double Function(SetLog) f) {
  var t = 0.0;
  for (final l in sets) {
    t += f(l);
  }
  return t > 0 ? t : null;
}

/// The charts offered depend on the exercise type.
List<Metric> metricsFor(ExType t) => switch (t) {
      ExType.weighted => [
          Metric('Max weight', 'kg', Agg.max, (s) => _best(s, (l) => l.weight)),
          Metric('Estimated 1RM', 'kg', Agg.max,
              (s) => _best(s, (l) => l.reps > 0 ? l.weight * (1 + l.reps / 30) : 0.0)),
          Metric('Volume', 'kg', Agg.sum, (s) => _total(s, (l) => l.weight * l.reps)),
        ],
      ExType.bodyweightPlus => [
          Metric('Added weight', 'kg', Agg.max, (s) => _best(s, (l) => l.weight)),
          Metric('Best set', 'reps', Agg.max, (s) => _best(s, (l) => l.reps.toDouble())),
          Metric('Total reps', 'reps', Agg.sum, (s) => _total(s, (l) => l.reps.toDouble())),
        ],
      ExType.bodyweight => [
          Metric('Best set', 'reps', Agg.max, (s) => _best(s, (l) => l.reps.toDouble())),
          Metric('Total reps', 'reps', Agg.sum, (s) => _total(s, (l) => l.reps.toDouble())),
        ],
      ExType.carry => [
          Metric('Max weight', 'kg', Agg.max, (s) => _best(s, (l) => l.weight)),
          Metric('Longest carry', 'm', Agg.max, (s) => _best(s, (l) => l.meters)),
          Metric('Total distance', 'm', Agg.sum, (s) => _total(s, (l) => l.meters)),
        ],
      ExType.timed => [
          Metric('Best hold', 'sec', Agg.max, (s) => _best(s, (l) => l.secs.toDouble())),
          Metric('Total time', 'sec', Agg.sum, (s) => _total(s, (l) => l.secs.toDouble())),
        ],
      ExType.cardio => [
          Metric('Pace', 'min/km', Agg.min,
              (s) => _best(s, (l) => l.km > 0 && l.secs > 0 ? l.secs / 60 / l.km : 0.0, lowest: true)),
          Metric('Distance', 'km', Agg.sum, (s) => _total(s, (l) => l.km)),
          Metric('Duration', 'min', Agg.sum, (s) => _total(s, (l) => l.secs / 60)),
          Metric('Speed', 'km/h', Agg.max, (s) => _best(s, (l) => l.km > 0 && l.secs > 0 ? l.km / (l.secs / 3600) : 0.0)),
        ],
    };

class Pt {
  final DateTime date;
  final double y;
  Pt(this.date, this.y);
}

DateTime _keyFor(DateTime d, Grouping g) => switch (g) {
      Grouping.session => d,
      Grouping.week => DateTime(d.year, d.month, d.day - (d.weekday - 1)), // Monday of that week
      Grouping.month => DateTime(d.year, d.month, 1),
    };

List<Pt> buildSeries(List<(DateTime, List<SetLog>)> hist, Metric m, Grouping g, int rangeDays) {
  final cutoff = DateTime.now().subtract(Duration(days: rangeDays));
  final groups = <DateTime, List<double>>{};
  for (final (date, sets) in hist) {
    if (rangeDays > 0 && date.isBefore(cutoff)) continue;
    final v = m.value(sets);
    if (v == null) continue;
    groups.putIfAbsent(_keyFor(date, g), () => []).add(v);
  }
  final out = <Pt>[];
  for (final e in groups.entries) {
    final vs = e.value;
    final y = switch (m.agg) {
      Agg.max => vs.reduce(max),
      Agg.min => vs.reduce(min),
      Agg.sum => vs.reduce((a, b) => a + b),
    };
    out.add(Pt(e.key, y));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

String axisNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String dateLabel(DateTime d, Grouping g) => g == Grouping.month
    ? "${_months[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}"
    : '${d.day}/${d.month}';

String setText(ExType t, SetLog l) => switch (t) {
      ExType.weighted => '${fmt(l.weight)} kg x ${l.reps}',
      ExType.bodyweightPlus => l.weight > 0 ? '+${fmt(l.weight)} kg x ${l.reps}' : 'BW x ${l.reps}',
      ExType.bodyweight => '${l.reps} reps',
      ExType.carry => '${fmt(l.weight)} kg x ${fmt(l.meters)} m',
      ExType.timed => '${l.secs} s',
      ExType.cardio => '${fmt(round2(l.secs / 60))} min, ${fmt(l.km)} km',
    };

// ===========================================================================
// Progress tab: weekly consistency + list of exercises you have trained
// ===========================================================================
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  Widget _weeklyChart() {
    final now = DateTime.now();
    final ws = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weeks = [for (var i = 7; i >= 0; i--) DateTime(ws.year, ws.month, ws.day - 7 * i)];
    final counts = [
      for (final w in weeks)
        store.sessions
            .where((s) => s.doneSets > 0 && !s.date.isBefore(w) && s.date.isBefore(DateTime(w.year, w.month, w.day + 7)))
            .length,
    ];
    final maxY = max(4, counts.reduce(max) + 1).toDouble();
    return SizedBox(
      height: 160,
      child: BarChart(BarChartData(
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: _small),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${weeks[i].day}/${weeks[i].month}', style: const TextStyle(fontSize: 10, color: greyText)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeks.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: counts[i].toDouble(), color: accent, width: 14, borderRadius: BorderRadius.circular(4)),
            ]),
        ],
      )),
    );
  }

  String _summary(Exercise e) {
    final hist = store.history(e.id);
    final ms = metricsFor(e.type);
    final m = ms.firstWhere((m) => hist.any((h) => m.value(h.$2) != null), orElse: () => ms.first);
    final vals = [
      for (final h in hist)
        if (m.value(h.$2) != null) m.value(h.$2)!,
    ];
    if (vals.isEmpty) return '${hist.length} sessions';
    final best = m.agg == Agg.min ? vals.reduce(min) : vals.reduce(max);
    return '${hist.length} sessions, best ${m.label.toLowerCase()} ${axisNum(best)} ${m.unit}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final thisMonth =
            store.sessions.where((s) => s.doneSets > 0 && s.date.year == now.year && s.date.month == now.month).length;
        final children = <Widget>[];
        for (final cat in categories) {
          final list = store.exercises.where((e) => e.category == cat && store.history(e.id).isNotEmpty).toList();
          if (list.isEmpty) continue;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(cat, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
          ));
          for (final e in list) {
            children.add(softCard(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(_summary(e)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ExerciseProgressScreen(exercise: e))),
              ),
            ));
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Progress')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            softCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sessions per week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text('$thisMonth sessions this month', style: const TextStyle(color: greyText, fontSize: 13)),
                  const SizedBox(height: 16),
                  _weeklyChart(),
                ]),
              ),
            ),
            if (children.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No exercise history yet. Tick sets as you finish them in a session, and your charts will appear here.',
                  style: TextStyle(color: greyText),
                ),
              ),
            ...children,
          ]),
        );
      },
    );
  }
}

// ===========================================================================
// Chart for one exercise
// ===========================================================================
class ExerciseProgressScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseProgressScreen({super.key, required this.exercise});
  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  late final List<Metric> metrics;
  late final List<(DateTime, List<SetLog>)> hist;
  int metricIdx = 0;
  Grouping g = Grouping.session;
  int range = 0; // days, 0 = all time

  Exercise get ex => widget.exercise;

  @override
  void initState() {
    super.initState();
    metrics = metricsFor(ex.type);
    hist = store.history(ex.id);
    final first = metrics.indexWhere((m) => hist.any((h) => m.value(h.$2) != null));
    metricIdx = first < 0 ? 0 : first;
  }

  Widget _chart(List<Pt> pts, Metric m) {
    final x0 = pts.first.date;
    final spots = [for (final p in pts) FlSpot(p.date.difference(x0).inDays.toDouble(), p.y)];
    var minX = spots.first.x, maxX = spots.last.x;
    if (maxX == minX) {
      minX -= 1;
      maxX += 1;
    }
    final lo = pts.map((p) => p.y).reduce(min), hi = pts.map((p) => p.y).reduce(max);
    final pad = hi == lo ? max(1.0, hi * 0.1) : (hi - lo) * 0.2;
    final minY = max(0.0, lo - pad), maxY = hi + pad;
    final interval = max(1.0, ((maxX - minX) / 4).ceilToDouble());
    String xLabel(double v) => dateLabel(x0.add(Duration(days: v.round())), g);

    return SizedBox(
      height: 260,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 12, 4),
        child: LineChart(LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                  return Text(axisNum(v), style: _small);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: interval,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(xLabel(v), style: _small),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${axisNum(t.y)} ${m.unit}\n${xLabel(t.x)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: accent,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0x1F3B5BDB)),
            ),
          ],
        )),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: _small),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = metrics[metricIdx];
    final pts = buildSeries(hist, m, g, range);
    final vals = pts.map((p) => p.y).toList();

    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        if (metrics.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 8, children: [
              for (var i = 0; i < metrics.length; i++)
                ChoiceChip(
                  label: Text(metrics[i].label),
                  selected: i == metricIdx,
                  onSelected: (_) => setState(() => metricIdx = i),
                ),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Grouping>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Grouping.session, label: Text('Session')),
              ButtonSegment(value: Grouping.week, label: Text('Weekly')),
              ButtonSegment(value: Grouping.month, label: Text('Monthly')),
            ],
            selected: {g},
            onSelectionChanged: (v) => setState(() => g = v.first),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 30, label: Text('1M')),
              ButtonSegment(value: 90, label: Text('3M')),
              ButtonSegment(value: 180, label: Text('6M')),
              ButtonSegment(value: 365, label: Text('1Y')),
              ButtonSegment(value: 0, label: Text('All')),
            ],
            selected: {range},
            onSelectionChanged: (v) => setState(() => range = v.first),
          ),
        ),
        const SizedBox(height: 12),
        softCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.label} (${m.unit})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (m.agg == Agg.min) const Text('Lower is better', style: TextStyle(color: greyText, fontSize: 13)),
              if (pts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No data for this view. Try a longer range or another chart.',
                        style: TextStyle(color: greyText)),
                  ),
                )
              else ...[
                _chart(pts, m),
                const SizedBox(height: 8),
                Row(children: [
                  _stat('Best', axisNum(m.agg == Agg.min ? vals.reduce(min) : vals.reduce(max))),
                  _stat('Latest', axisNum(vals.last)),
                  _stat(
                    'Change',
                    vals.length > 1 ? '${vals.last - vals.first > 0 ? '+' : ''}${axisNum(vals.last - vals.first)}' : '-',
                  ),
                ]),
              ],
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('Recent sessions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
        ),
        for (final h in hist.reversed.take(8))
          softCard(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${h.$1.day}/${h.$1.month}/${h.$1.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(h.$2.map((l) => setText(ex.type, l)).join(',  ')),
            ),
          ),
      ]),
    );
  }
}
