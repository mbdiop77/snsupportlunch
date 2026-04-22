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

    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadStats();
    });
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
                'total_passages': (s.first['total_passages'] as num? ?? 0).toInt(),
              }
            : {'meals_taken': 0, 'passages_without_meal': 0, 'total_passages': 0};

        hourly = h is List ? List<Map<String, dynamic>>.from(h) : [];
      });
    } catch (e) {
      debugPrint("Erreur loadStats: $e");
    }
  }

  String formatTime(String? iso) {
    if (iso == null) return "--";
    final dt = DateTime.tryParse(iso);
    if (dt == null) return "--";
    return DateFormat.Hm().format(dt);
  }

  Stream<List<Map<String, dynamic>>> streamToday() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return supabase.from('scans_meal').stream(primaryKey: ['id']).eq('scan_date', today);
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

          scans.sort((a, b) => (a['scanned_at'] ?? '').compareTo(b['scanned_at'] ?? ''));

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

          // 🔥 NOUVEAUX CALCULS
          final consumptionRate = maxMeals > 0 ? (mealsTaken / maxMeals * 100) : 0;

          double flowRate = 0;
          if (hourly.isNotEmpty) {
            final total = hourly.fold<num>(0, (sum, e) => sum + (e['total'] as num));
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

          double avgInterval = 0;
          if (scans.length > 1) {
            List<DateTime> times = scans
                .map((e) => DateTime.tryParse(e['scanned_at'] ?? ''))
                .whereType<DateTime>()
                .toList();

            times.sort();

            int totalSeconds = 0;
            for (int i = 1; i < times.length; i++) {
              totalSeconds += times[i].difference(times[i - 1]).inSeconds;
            }

            avgInterval = totalSeconds / (times.length - 1);
          }

          final isIntervalAlert = avgInterval > 1800; // 30 min

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                kpiCard("Repas servis", mealsTaken, Icons.restaurant, Colors.green, isWide, width),
                kpiCard("Sans repas", passagesWithoutMeal, Icons.block, Colors.red, isWide, width),
                kpiCard("Total passages", totalPassages, Icons.people, Colors.blue, isWide, width),
                kpiCard("Repas restants", remaining, Icons.inventory, Colors.orange, isWide, width),

                kpiCard("Premier scan", firstScan, Icons.access_time, Colors.purple, isWide, width, isText: true),
                kpiCard("Dernier scan", lastScan, Icons.access_time, Colors.purple, isWide, width, isText: true),

                // 🔥 NOUVEAUX KPI
                kpiCard("Taux conso", "${consumptionRate.toStringAsFixed(1)}%", Icons.percent, Colors.teal, isWide, width, isText: true),
                kpiCard("Débit /h", flowRate.toStringAsFixed(1), Icons.speed, Colors.indigo, isWide, width, isText: true),
                kpiCard("Heure de pointe", "${peakHour}h", Icons.timeline, Colors.deepPurple, isWide, width, isText: true),

                kpiCard(
                  "Intervalle moyen",
                  "${avgInterval.toStringAsFixed(0)} s",
                  Icons.timer,
                  isIntervalAlert ? Colors.red : Colors.brown,
                  isWide,
                  width,
                  isText: true,
                ),

                // 🚨 ALERTE VISUELLE
                if (isIntervalAlert)
                  SizedBox(
                    width: isWide ? width / 2 : width,
                    child: Card(
                      color: Colors.red.withValues(alpha: 0.1),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 10),
                            Text("⚠️ Intervalle trop élevé (> 30 min)")
                          ],
                        ),
                      ),
                    ),
                  ),

                SizedBox(width: isWide ? width / 4 - 20 : width, child: mealGauge(mealsTaken)),
                SizedBox(width: isWide ? width / 4 - 20 : width, height: 300, child: scansChart()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget kpiCard(String title, dynamic value, IconData icon, Color color, bool isWide, double width,
      {bool isText = false}) {
    final displayWidth = isWide ? width / 4 - 20 : width;
    return SizedBox(
      width: displayWidth,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isText
                      ? Text(value.toString(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                      : TweenAnimationBuilder(
                          tween: IntTween(begin: 0, end: (value as int? ?? 0)),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, val, child) {
                            return Text("$val",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                          },
                        ),
                  Text(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mealGauge(int taken) {
    final remaining = maxMeals - taken;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Répartition des repas", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(value: taken.toDouble(), title: "Servis", color: Colors.green, radius: 60),
                    PieChartSectionData(value: remaining.toDouble(), title: "Restants", color: Colors.orange, radius: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget scansChart() {
  if (hourly.isEmpty) {
    return const SizedBox();
  }

  // 🔥 Détection heure de pointe
  int peakIndex = 0;
  int maxValue = 0;

  for (int i = 0; i < hourly.length; i++) {
    final val = (hourly[i]['total'] as num).toInt();
    if (val > maxValue) {
      maxValue = val;
      peakIndex = i;
    }
  }

  final barGroups = hourly.asMap().entries.map((entry) {
    final index = entry.key;
    final e = entry.value;

    final value = (e['total'] as num).toDouble();
    final isPeak = index == peakIndex;

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 18,
          borderRadius: BorderRadius.circular(6),
          color: isPeak ? Colors.red : Colors.blue, // 🔥 pic en rouge
        ),
      ],
    );
  }).toList();

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            "Flux des scans par heure",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),

                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= hourly.length) {
                          return const SizedBox();
                        }
                        final hour = hourly[index]['hour'];
                        return Text(
                          "${hour}h",
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),

                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
