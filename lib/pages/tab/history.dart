import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/history_csv.dart';

final supabase = Supabase.instance.client;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _scans = [];
  String _searchText = "";

  final Set<int> _newIds = {};
  final Set<int> _previousIds = {};

  late final RealtimeChannel _channel;

  DateTime _selectedDate = DateTime.now();

  int totalPassage = 0;
  int totalMeals = 0;
  int refusedMeals = 0;

  @override
  void initState() {
    super.initState();

    _loadScans();

    _channel = supabase.channel('scans_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'scans_meal',
        callback: (payload) {
          _loadScans();
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    supabase.removeChannel(_channel);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {

    final formattedDate =
        DateFormat('yyyy-MM-dd').format(_selectedDate);

    final response = await supabase.rpc(
      'get_scans_by_date',
      params: {'p_date': formattedDate},
    );

    final data = List<Map<String, dynamic>>.from(response);

    totalPassage = data.length;
    totalMeals = data.where((e) => e['took_meal'] == true).length;
    refusedMeals = data.where((e) => e['took_meal'] == false).length;

    for (var scan in data) {
      final id = scan['id'] ?? scan['scanned_at'].hashCode;

      if (!_previousIds.contains(id)) {
        _newIds.add(id);
      }
    }

    _previousIds
      ..clear()
      ..addAll(data.map((s) => s['id'] ?? s['scanned_at'].hashCode));

    setState(() {
      _scans = data;
    });

    if (_newIds.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _newIds.clear());
      });
    }
  }

  void previousDay() {
    final limit = DateTime.now().subtract(const Duration(days: 7));

    if (_selectedDate.isAfter(limit)) {
      setState(() {
        _selectedDate =
            _selectedDate.subtract(const Duration(days: 1));
      });

      _loadScans();
    }
  }

  void nextDay() {
    if (_selectedDate.isBefore(DateTime.now())) {
      setState(() {
        _selectedDate =
            _selectedDate.add(const Duration(days: 1));
      });

      _loadScans();
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    DateTime dt =
        value is String ? DateTime.parse(value) : value;

    return DateFormat.Hm().format(dt);
  }

  @override
  Widget build(BuildContext context) {

    final filtered = _scans.where((scan) {

      final q = _searchText.toLowerCase();

      final matricule =
          (scan['matricule'] ?? '').toString().toLowerCase();
      final nom =
          (scan['nom'] ?? '').toString().toLowerCase();
      final prenom =
          (scan['prenom'] ?? '').toString().toLowerCase();

      return matricule.contains(q) ||
          nom.contains(q) ||
          prenom.contains(q);

    }).toList();

    double width = MediaQuery.of(context).size.width;

    double containerWidth =
        width > 900 ? width * 0.6 : width;

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: containerWidth,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [

              /// HEADER
              SliverAppBar(
                pinned: true,
                    backgroundColor: Colors.white,
                    toolbarHeight: 30,
                    titleSpacing: 8,
                    title: const Text(
                      "Historique distribution des repas",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                centerTitle: true,
                actions: [

                  IconButton(
                    icon: const Icon(Icons.download,color: Colors.black),
                    onPressed: filtered.isEmpty
                        ? null
                        : () => exportToPDF(filtered),
                  )

                ],
              ),

              /// NAVIGATION DATE
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [

                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: previousDay,
                      ),

                      Text(
                        DateFormat('dd MMM yyyy')
                            .format(_selectedDate),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),

                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: nextDay,
                      )

                    ],
                  ),
                ),
              ),

              /// KPI CARDS
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [

                      _kpiCard(
                          "Passages",
                          totalPassage.toString(),
                          Icons.qr_code_scanner,
                          Colors.blue),

                      _kpiCard(
                          "Repas servis",
                          totalMeals.toString(),
                          Icons.restaurant,
                          Colors.green),

                      _kpiCard(
                          "Refus",
                          refusedMeals.toString(),
                          Icons.cancel,
                          Colors.red),

                    ],
                  ),
                ),
              ),

              /// SEARCH
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Rechercher (ex: prenom,nom)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _searchText = v;
                      });
                    },
                  ),
                ),
              ),

              /// TABLE HEADER
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.grey.shade200,
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [

                    //  Expanded(
                    //      flex: 2,
                   //       child: Text("Matricule",
                      //        style: TextStyle(
                      //            fontWeight:
                          //            FontWeight.bold))),

                      Expanded(
                          flex: 3,
                          child: Text("Prenom-nom",
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold))),

                      Expanded(
                          flex: 3,
                          child: Text("Repas",
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold))),

                      Expanded(
                          flex: 1,
                          child: Text("Heure",
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold))),

                      Expanded(
                          flex: 1,
                          child: Text("Statut",
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold))),

                    ],
                  ),
                ),
              ),

              /// LISTE
              SliverList(
                delegate: SliverChildBuilderDelegate(

                  (context, index) {

                    final scan = filtered[index];
                    final id =
                        scan['id'] ??
                        scan['scanned_at'].hashCode;

                    return Container(

                      color: _newIds.contains(id)
                          ? Colors.green.shade50
                          : Colors.white,

                      child: Column(
                        children: [

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6),

                            child: Row(
                              children: [

                             //   Expanded(
                              //      flex: 2,
                              //      child: Text(
                                //        scan['matricule']
                                 //           ?? '')),

                                Expanded(
                                    flex: 3,
                                    child: Text(   
                                "${scan['prenom'] ?? ''}${(scan['nom'] != null && scan['nom'].toString().trim().isNotEmpty) ? ' ${scan['nom']}' : ''}"                                        )),

                                Expanded(
                                    flex: 3,
                                    child: Text(
                                        scan['dish'] ??
                                            'Aucun')),

                                Expanded(
                                    flex: 1,
                                    child: Text(formatTime(
                                        scan['scanned_at']))),

                                Expanded(
                                  flex: 1,
                                  child: Icon(
                                    scan['took_meal']
                                            == true
                                        ? Icons
                                            .check_circle
                                        : Icons.cancel,
                                    color: scan['took_meal']
                                            == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),

                              ],
                            ),
                          ),

                          const Divider(height: 1)

                        ],
                      ),
                    );
                  },

                  childCount: filtered.length,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(
      String title,
      String value,
      IconData icon,
      Color color) {

    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 4)
        ],
      ),
      child: Row(
        children: [

          Icon(icon,color: color,size: 30),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              Text(title,
                  style: const TextStyle(
                      fontSize: 13)),

              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold))

            ],
          )
        ],
      ),
    );
  }
}