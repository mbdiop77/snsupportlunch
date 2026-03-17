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

    // Rafraîchissement automatique toutes les 10 secondes
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

          // Trier pour premier / dernier scan
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
    final spots = hourly
        .map((e) => FlSpot((e['hour'] as num).toDouble(), (e['total'] as num).toDouble()))
        .toList();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Flux des scans par heure", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(spots: spots, isCurved: true, barWidth: 4, dotData: FlDotData(show: false)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}