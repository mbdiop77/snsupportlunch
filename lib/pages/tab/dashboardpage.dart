import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Stream<List<Map<String, dynamic>>> streamToday() {
    return supabase.from('employees_today').stream(primaryKey: ['matricule']);
  }

  String formatTime(String? iso) {
    if (iso == null) return "--";
    final dt = DateTime.tryParse(iso);
    if (dt == null) return "--";
    return DateFormat.Hm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: streamToday(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final employees = snapshot.data!;

        /// Calculs KPI
        final totalMeals = employees.length;
        final totalEmployees = employees.length;
        final maxMeals = 300;
        final remaining = maxMeals - totalMeals;

        /// Premier et dernier scan
        String firstScan = "--";
        String lastScan = "--";
        if (employees.isNotEmpty) {
          employees.sort((a, b) =>
              (a['last_scan_time'] ?? '').compareTo(b['last_scan_time'] ?? ''));
          firstScan = formatTime(employees.first['last_scan_time']);
          lastScan = formatTime(employees.last['last_scan_time']);
        }

        return Scaffold(

          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width > 900;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: [
                  // KPI Cards
                  ...[
                    ["Repas servis", totalMeals.toString(), Icons.restaurant, Colors.green],
                    ["Employés servis", totalEmployees.toString(), Icons.people, Colors.blue],
                    ["Restants", remaining.toString(), Icons.inventory, Colors.orange],
                    ["Premier scan", firstScan, Icons.access_time, Colors.purple],
                    ["Dernier scan", lastScan, Icons.access_time, Colors.purple], // Ici on met lastScan
                  ].map((item) {
                    return SizedBox(
                      width: isWide ? (width / 3) - 24 : width,
                      child: _kpiCard(
                        item[0] as String,
                        item[1] as String,
                        item[2] as IconData,
                        item[3] as Color,
                      ),
                    );
                  }),
                
                    // Graphique
                    SizedBox(
                      width: isWide ? (width / 1) - 24 : width,
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                "Flux des scans",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 140, // hauteur fixe pour éviter bottom overflow
                                child: _buildChart(employees),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// KPI Card
  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 38), // remplace withOpacity
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Graphique
  Widget _buildChart(List employees) {
    List<FlSpot> spots = employees
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.key.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}