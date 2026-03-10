import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/history_csv.dart'; // ta fonction export existe ici

final supabase = Supabase.instance.client;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _newScans = {};
  final Set<String> _previousMatricules = {};
  String _searchText = '';

  Stream<List<Map<String, dynamic>>> streamTodayScans() {
    return supabase
        .from('employees_today')
        .stream(primaryKey: ['matricule']);
  }

  String formatTime(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    return DateFormat.Hm().format(dt);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: streamTodayScans(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        List<Map<String, dynamic>> employees = snapshot.data!;

        // Tri : derniers scans en haut
        employees.sort((a, b) {
          final aTime = a['last_scan_time'] ?? '';
          final bTime = b['last_scan_time'] ?? '';
          if (aTime == '' || bTime == '') return 0;
          return bTime.compareTo(aTime);
        });

        // Détecter nouveaux scans pour animation verte
        for (var emp in employees) {
          final matricule = emp['matricule'].toString();
          if (!_previousMatricules.contains(matricule)) {
            _newScans.add(matricule);
          }
        }
        _previousMatricules
          ..clear()
          ..addAll(employees.map((e) => e['matricule'].toString()));

        // Supprimer l'animation verte après 2 secondes
        if (_newScans.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _newScans.clear();
              });
            }
          });
        }

        // Filtrage recherche
        if (_searchText.isNotEmpty) {
          employees = employees.where((emp) {
            final query = _searchText.toLowerCase();
            final matricule = emp['matricule'].toString().toLowerCase();
            final nom = emp['nom'].toString().toLowerCase();
            final prenom = emp['prenom'].toString().toLowerCase();
            return matricule.contains(query) ||
                nom.contains(query) ||
                prenom.contains(query);
          }).toList();
        }

        double containerWidth = MediaQuery.of(context).size.width > 850
            ? MediaQuery.of(context).size.width / 2
            : MediaQuery.of(context).size.width;

        // Scroll automatique vers le dernier scan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return Scaffold(
          body: Center(
            child: SizedBox(
              width: containerWidth,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // SliverAppBar fixe et compacte
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 25,
                    flexibleSpace: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              "Liste des personnes déjà servies",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: employees.isEmpty
                                ? null
                                : () => exportToCSV(employees),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text("Exporter CSV",
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Zone Total repas + Recherche
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Total repas : ${employees.length}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Recherche...',
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 8),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(6)),
                                ),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchText = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Header table
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      color: Colors.grey.shade200,
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text("Matricule",
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false)),
                          Expanded(
                              flex: 3,
                              child: Text("Nom",
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false)),
                          Expanded(
                              flex: 3,
                              child: Text("Repas",
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false)),
                          Expanded(
                              flex: 1,
                              child: Text("Heure",
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false)),
                        ],
                      ),
                    ),
                  ),

                  // Liste des employés
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final emp = employees[index];
                        final matricule = emp['matricule'].toString();
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              color: _newScans.contains(matricule)
                                  ? Colors.green.shade50
                                  : Colors.white,
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 2,
                                      child: Text(matricule,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500))),
                                  Expanded(
                                      flex: 3,
                                      child: Text(
                                          "${emp['prenom']} ${emp['nom']}")),
                                  Expanded(
                                      flex: 3,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(emp['meal_scans'].toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal)),
                                      )),
                                  Expanded(
                                      flex: 1,
                                      child: Text(formatTime(emp['last_scan_time']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w400,))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1),
                          ],
                        );
                      },
                      childCount: employees.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}