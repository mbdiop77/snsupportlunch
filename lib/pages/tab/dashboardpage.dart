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
  int maxMeals = 0;
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

    // ✅ NOUVELLE PARTIE (capacité réelle)
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final capacityRes = await supabase
        .from('daily_menu')
        .select('quantity')
        .eq('menu_date', today);

    int totalCapacity = 0;
      totalCapacity = capacityRes.fold<int>(
        0,
        (sum, e) => sum + ((e['quantity'] as num?)?.toInt() ?? 0),
      );


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

      // ✅ ICI on remplace le 300
      maxMeals = totalCapacity;
    });
  } catch (e) {
    debugPrint("Erreur loadStats: $e");
  }
}

  String formatTime(String? iso) {
    if (iso == null) return "--";
    final dt = DateTime.tryParse(iso);
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
            child: Column(
              children: [

                // ================= KPI =================
                // ================= ALERT =================
                if (isIntervalAlert &&
                    DateTime.now().hour >= 12 &&
                    DateTime.now().hour < 18)
                  SizedBox(
                    width: double.infinity, // ✅ pleine largeur
                    child: Card(
                      color: Colors.red.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.red),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // 🔴 ICÔNE WARNING
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 22,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 📝 TEXTE
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          "aucun scan depuis ${formatDuration(secondsSinceLastScan)}",
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 05),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
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
                    kpiCard("Débit /h", flowRate.toStringAsFixed(1),
                        Icons.speed, Colors.indigo, isWide, width,
                        isText: true),
                    kpiCard("Heure de pointe", "${peakHour}h",
                        Icons.timeline, Colors.deepPurple, isWide, width,
                        isText: true),
                 //   kpiCard(
                   //     "Dernier scan",
                     //   formatDuration(secondsSinceLastScan),
                    //    Icons.timer,
                      //  isIntervalAlert ? Colors.red : Colors.green,
                      //  isWide,
                      //  width,
                      //  isText: true),
                  ],
                ),

                const SizedBox(height: 20),

                

                // ================= CHARTS =================
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 280,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: mealGauge(mealsTaken),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 280,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: scansChart(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 250,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: mealGauge(mealsTaken),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 250,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: scansChart(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
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
    final displayWidth = isWide ? width / 4 - 20 : width;

    return SizedBox(
      width: displayWidth,
      height: 85,
      child: Card(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text("$value\n$title"),
            ),
          ],
        ),
      ),
    );
  }

  Widget mealGauge(int taken) {
    final remaining = maxMeals - taken;

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(value: taken.toDouble(), color: Colors.green),
          PieChartSectionData(value: remaining.toDouble(), color: Colors.orange),
        ],
      ),
    );
  }

Widget scansChart() {
  if (hourly.isEmpty) {
    return const Center(child: Text("Aucune donnée"));
  }

  final barGroups = hourly.asMap().entries.map((entry) {
    final index = entry.key;
    final value = (entry.value['total'] as num).toDouble();

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }).toList();

  return BarChart(
    BarChartData(
      minY: 0,

      // ✅ AXES CONFIGURÉS PROPREMENT
      titlesData: FlTitlesData(
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false), // ❌ supprimé
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false), // ❌ supprimé
        ),

        // ✅ AXE HORIZONTAL = HEURES
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= hourly.length) {
                return const SizedBox();
              }

              final hour = hourly[index]['hour'];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text("${hour}h",
                    style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),

        // ✅ AXE VERTICAL = PAS DE 5
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),

      // ✅ GRID PROPRE
      gridData: FlGridData(
        show: true,
        horizontalInterval: 5,
      ),

      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(),
          bottom: BorderSide(),
        ),
      ),

      barGroups: barGroups,
    ),
  );
}
}