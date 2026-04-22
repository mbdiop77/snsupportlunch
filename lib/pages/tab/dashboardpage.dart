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

  Map<String, int> stats = {
    'meals_taken': 0,
    'passages_without_meal': 0,
    'total_passages': 0,
  };

  List<Map<String, dynamic>> hourly = [];
  static const int maxMeals = 300;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadStats();
    refreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => loadStats());
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
        stats = s is List && s.isNotEmpty
            ? {
                'meals_taken': (s.first['meals_taken'] as num? ?? 0).toInt(),
                'passages_without_meal':
                    (s.first['passages_without_meal'] as num? ?? 0).toInt(),
                'total_passages':
                    (s.first['total_passages'] as num? ?? 0).toInt(),
              }
            : {
                'meals_taken': 0,
                'passages_without_meal': 0,
                'total_passages': 0
              };

        hourly = h is List ? List<Map<String, dynamic>>.from(h) : [];
      });
    } catch (e) {
      debugPrint("Erreur loadStats: $e");
    }
  }

  String formatTime(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    return dt != null ? DateFormat.Hm().format(dt) : "--";
  }

  String formatDuration(int seconds) {
    if (seconds < 60) return "$seconds s";
    if (seconds < 3600) return "${(seconds / 60).toStringAsFixed(1)} min";
    return "${(seconds / 3600).toStringAsFixed(1)} h";
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamToday(),
        builder: (context, snapshot) {
          final scans = snapshot.data ?? [];

          scans.sort((a, b) =>
              (a['scanned_at'] ?? '').compareTo(b['scanned_at'] ?? ''));

          String firstScan = "--";
          String lastScan = "--";

          if (scans.isNotEmpty) {
            firstScan = formatTime(scans.first['scanned_at']);
            lastScan = formatTime(scans.last['scanned_at']);
          }

          final mealsTaken = stats['meals_taken'] ?? 0;
          final passagesWithoutMeal = stats['passages_without_meal'] ?? 0;
          final totalPassages = stats['total_passages'] ?? 0;
          final remaining = maxMeals - mealsTaken;

          final consumptionRate =
              maxMeals > 0 ? (mealsTaken / maxMeals * 100) : 0;

          double flowRate = 0;
          if (hourly.isNotEmpty) {
            final total =
                hourly.fold<num>(0, (sum, e) => sum + (e['total'] as num));
            flowRate = total / hourly.length;
          }

          int peakHour = 0;
          int maxValue = 0;
          for (var e in hourly) {
            final val = (e['total'] as num).toInt();
            if (val > maxValue) {
              maxValue = val;
              peakHour = (e['hour'] as num).toInt();
            }
          }

          int secondsSinceLastScan = 0;
          if (scans.isNotEmpty) {
            final last = DateTime.tryParse(scans.last['scanned_at'] ?? '');
            if (last != null) {
              secondsSinceLastScan =
                  DateTime.now().difference(last).inSeconds;
            }
          }

          final isIntervalAlert = secondsSinceLastScan > 1800;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                kpiCard("Repas servis", mealsTaken, Icons.restaurant,
                    Colors.green, isWide, width),
                kpiCard("Sans repas", passagesWithoutMeal, Icons.block,
                    Colors.red, isWide, width),
                kpiCard("Total passages", totalPassages, Icons.people,
                    Colors.blue, isWide, width),
                kpiCard("Repas restants", remaining, Icons.inventory,
                    Colors.orange, isWide, width),

                kpiCard("Premier scan", firstScan, Icons.access_time,
                    Colors.purple, isWide, width,
                    isText: true),
                kpiCard("Dernier scan", lastScan, Icons.access_time,
                    Colors.purple, isWide, width,
                    isText: true),

                kpiCard(
                    "Taux conso",
                    "${consumptionRate.toStringAsFixed(1)}%",
                    Icons.percent,
                    Colors.teal,
                    isWide,
                    width,
                    isText: true),

                kpiCard("Débit /h", flowRate.toStringAsFixed(1), Icons.speed,
                    Colors.indigo, isWide, width,
                    isText: true),

                kpiCard("Heure de pointe", "${peakHour}h", Icons.timeline,
                    Colors.deepPurple, isWide, width,
                    isText: true),

                kpiCard(
                    "Dernier scan",
                    formatDuration(secondsSinceLastScan),
                    Icons.timer,
                    isIntervalAlert ? Colors.red : Colors.green,
                    isWide,
                    width,
                    isText: true),

                if (isIntervalAlert)
                  Card(
                    color: Colors.red.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "⚠️ Aucun scan depuis ${formatDuration(secondsSinceLastScan)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                mealGauge(mealsTaken),
                scansChart(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget kpiCard(String title, dynamic value, IconData icon, Color color,
      bool isWide, double width,
      {bool isText = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.toString(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget mealGauge(int taken) {
    final remaining = maxMeals - taken;

    return Card(
      child: SizedBox(
        height: 250,
        child: PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(value: taken.toDouble(), color: Colors.green),
              PieChartSectionData(
                  value: remaining.toDouble(), color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget scansChart() {
    if (hourly.isEmpty) {
      return const SizedBox(height: 200);
    }

    final barGroups = hourly.asMap().entries.map((entry) {
      final index = entry.key;
      final value = (entry.value['total'] as num).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: value, width: 16),
        ],
      );
    }).toList();

    return Card(
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            gridData:
                FlGridData(show: true, horizontalInterval: 5),
            borderData: FlBorderData(
                show: true,
                border: const Border(
                    left: BorderSide(), bottom: BorderSide())),
            titlesData: FlTitlesData(
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  reservedSize: 30,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i >= hourly.length) return const SizedBox();
                    return Text("${hourly[i]['hour']}h");
                  },
                ),
              ),
            ),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }
}