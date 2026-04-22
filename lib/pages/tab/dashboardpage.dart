import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  static const int maxMeals = 300;

  Timer? refreshTimer;

  Map<String, int> stats = {};
  List<Map<String, dynamic>> hourly = [];

  @override
  void initState() {
    super.initState();
    loadStats();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => loadStats());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadStats() async {
    try {
      final s = await supabase.rpc('today_meal_stats');
      final h = await supabase.rpc('scans_by_hour');

      if (!mounted) return;

      setState(() {
        stats = _parseStats(s);
        hourly = _parseHourly(h);
      });
    } catch (_) {}
  }

  Map<String, int> _parseStats(dynamic s) {
    if (s is List && s.isNotEmpty) {
      return {
        'meals_taken': (s.first['meals_taken'] as num? ?? 0).toInt(),
        'passages_without_meal': (s.first['passages_without_meal'] as num? ?? 0).toInt(),
        'total_passages': (s.first['total_passages'] as num? ?? 0).toInt(),
      };
    }
    return {'meals_taken': 0, 'passages_without_meal': 0, 'total_passages': 0};
  }

  List<Map<String, dynamic>> _parseHourly(dynamic h) {
    return h is List ? List<Map<String, dynamic>>.from(h) : [];
  }

  Stream<List<Map<String, dynamic>>> streamToday() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return supabase
        .from('scans_meal')
        .stream(primaryKey: ['id'])
        .eq('scan_date', today);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamToday(),
        builder: (context, snapshot) {
          final scans = snapshot.data ?? [];

          final computed = DashboardCalculator.compute(stats, hourly, scans);

          return DashboardView(
            isWide: isWide,
            computed: computed,
          );
        },
      ),
    );
  }
}

// ================= CALCULATOR =================
class DashboardCalculator {
  static DashboardData compute(
    Map<String, int> stats,
    List<Map<String, dynamic>> hourly,
    List<Map<String, dynamic>> scans,
  ) {
    scans.sort((a, b) => (a['scanned_at'] ?? '').compareTo(b['scanned_at'] ?? ''));

    final mealsTaken = stats['meals_taken'] ?? 0;
    final remaining = _remaining(mealsTaken);

    return DashboardData(
      mealsTaken: mealsTaken,
      passagesWithoutMeal: stats['passages_without_meal'] ?? 0,
      totalPassages: stats['total_passages'] ?? 0,
      remaining: remaining,
      consumptionRate: _consumption(mealsTaken),
      flowRate: _flow(hourly),
      peakHour: _peak(hourly),
      avgInterval: _interval(scans),
      firstScan: _format(scans.isNotEmpty ? scans.first['scanned_at'] : null),
      lastScan: _format(scans.isNotEmpty ? scans.last['scanned_at'] : null),
      hourly: hourly,
    );
  }

  static int _remaining(int taken) => _DashboardPageState.maxMeals - taken;

  static double _consumption(int taken) =>
      _DashboardPageState.maxMeals > 0 ? (taken / _DashboardPageState.maxMeals * 100) : 0;

  static double _flow(List<Map<String, dynamic>> hourly) {
    if (hourly.isEmpty) return 0;
    final total = hourly.fold<num>(0, (s, e) => s + (e['total'] as num));
    return total / hourly.length;
  }

  static int _peak(List<Map<String, dynamic>> hourly) {
    int peak = 0, max = 0;
    for (var e in hourly) {
      final val = (e['total'] as num).toInt();
      if (val > max) {
        max = val;
        peak = (e['hour'] as num).toInt();
      }
    }
    return peak;
  }

  static double _interval(List<Map<String, dynamic>> scans) {
    if (scans.length < 2) return 0;

    final times = scans
        .map((e) => DateTime.tryParse(e['scanned_at'] ?? ''))
        .whereType<DateTime>()
        .toList()
      ..sort();

    int total = 0;
    for (int i = 1; i < times.length; i++) {
      total += times[i].difference(times[i - 1]).inSeconds;
    }

    return total / (times.length - 1);
  }

  static String _format(String? iso) {
    if (iso == null) return "--";
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat.Hm().format(dt) : "--";
  }
}

// ================= MODEL =================
class DashboardData {
  final int mealsTaken;
  final int passagesWithoutMeal;
  final int totalPassages;
  final int remaining;
  final double consumptionRate;
  final double flowRate;
  final int peakHour;
  final double avgInterval;
  final String firstScan;
  final String lastScan;
  final List<Map<String, dynamic>> hourly;

  DashboardData({
    required this.mealsTaken,
    required this.passagesWithoutMeal,
    required this.totalPassages,
    required this.remaining,
    required this.consumptionRate,
    required this.flowRate,
    required this.peakHour,
    required this.avgInterval,
    required this.firstScan,
    required this.lastScan,
    required this.hourly,
  });
}

// ================= UI =================
class DashboardView extends StatelessWidget {
  final bool isWide;
  final DashboardData computed;

  const DashboardView({super.key, required this.isWide, required this.computed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ..._kpis(context),
          ChartCard(hourly: computed.hourly, isWide: isWide),
        ],
      ),
    );
  }

  List<Widget> _kpis(BuildContext context) {
    return [
      KpiCard("Repas", computed.mealsTaken, Icons.restaurant, Colors.green),
      KpiCard("Restants", computed.remaining, Icons.inventory, Colors.orange),
      KpiCard("Conso", "${computed.consumptionRate.toStringAsFixed(1)}%", Icons.percent, Colors.teal, isText: true),
      KpiCard("Débit", computed.flowRate.toStringAsFixed(1), Icons.speed, Colors.indigo, isText: true),
      KpiCard("Pic", "${computed.peakHour}h", Icons.timeline, Colors.purple, isText: true),
      KpiCard("Intervalle", "${computed.avgInterval.toStringAsFixed(1)}s", Icons.timer, Colors.brown, isText: true),
    ];
  }
}

class KpiCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;
  final Color color;
  final bool isText;

  const KpiCard(this.title, this.value, this.icon, this.color, {this.isText = false, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 900
          ? MediaQuery.of(context).size.width / 4 - 20
          : double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(title)
              ])
            ],
          ),
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> hourly;
  final bool isWide;

  const ChartCard({super.key, required this.hourly, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final spots = hourly
        .map((e) => FlSpot((e['hour'] as num).toDouble(), (e['total'] as num).toDouble()))
        .toList();

    return SizedBox(
      width: isWide ? MediaQuery.of(context).size.width / 2 : double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(spots: spots, isCurved: true, barWidth: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
