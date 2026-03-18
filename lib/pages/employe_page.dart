import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
import '../features/menu_du_jour_sheet.dart';
import '../features/suggestion_dialog.dart';
import '../services/qr_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployePage extends StatefulWidget {
  final Map<String, dynamic> employee;
  const EmployePage({super.key, required this.employee});

  @override
  State<EmployePage> createState() => _DynamicQRState();
}

class _DynamicQRState extends State<EmployePage> {
  int restants = 0;
  String qrData = "";
  DateTime? weekStart;
  DateTime? weekEnd;

  Timer? _timer;
  late final RealtimeChannel _channel;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    _initData();
    _startQRRefresh();
    _initRealtime();
  }

  /// ==============================
  /// INIT GLOBAL
  /// ==============================

  Future<void> _initData() async {
    generateQR();
    await loadWeeklyMeals();
  }

  /// ==============================
  /// QR DYNAMIQUE
  /// ==============================

  void _startQRRefresh() {
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => generateQR(),
    );
  }

  void generateQR() {
    final matricule = widget.employee['matricule'];

    setState(() {
      qrData = QrService.generateQR(matricule);
    });
  }

  /// ==============================
  /// LOAD DATA
  /// ==============================

  Future<void> loadWeeklyMeals() async {
    try {
      final response = await supabase.rpc(
        'get_user_week_meals',
        params: {'p_employee_id': widget.employee['id']},
      );

      final data = List<Map<String, dynamic>>.from(response ?? []);

      if (data.isEmpty || !mounted) return;

      setState(() {
        weekStart = DateTime.parse(data[0]['week_start']);
        weekEnd = DateTime.parse(data[0]['week_end']);
        restants = data[0]['remaining_meals'] ?? restants;
      });

    } catch (e) {
      debugPrint("Erreur loadWeeklyMeals: $e");
    }
  }

  /// ==============================
  /// REALTIME
  /// ==============================

  void _initRealtime() {
    _channel = supabase
        .channel('scans_meal_live')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans_meal',
          callback: (payload) async {

            if (!mounted) return;

            final newRecord = payload.newRecord;

            /// 🎯 Filtrer uniquement cet employé
            if (newRecord['employee_id'] == widget.employee['id']) {

              /// 🔄 refresh uniquement si nécessaire
              await loadWeeklyMeals();
            }
          },
        )
        ..subscribe();
  }

  /// ==============================
  /// UI
  /// ==============================

  @override
  Widget build(BuildContext context) {
    final fullName =
        "${widget.employee['prenom'] ?? ''}"
        "${(widget.employee['nom'] != null && widget.employee['nom'].toString().trim().isNotEmpty) ? ' ${widget.employee['nom']}' : ''}";

    return Scaffold(
      appBar: AppBar(
        elevation: 10,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(fontSize: 12, color: Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [

          /// 💬 Suggestion
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              SuggestionDialog.show(context, (text) async {
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await supabase.from('comment').insert({
                    'comment_text': text,
                  });

                  messenger.showSnackBar(
                    const SnackBar(content: Text("Merci 🙏")),
                  );

                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text("Erreur: $e")),
                  );
                }
              });
            },
          ),

          /// 🍽 Restants
          Tooltip(
            message: weekStart != null && weekEnd != null
                ? "Du ${weekStart!.day}/${weekStart!.month} au ${weekEnd!.day}/${weekEnd!.month}"
                : "Chargement...",
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.restaurant, color: Colors.black),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    restants.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 🚪 Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await context.read<SessionProvider>().logout();
            },
          ),
        ],
      ),

      /// 📲 QR
      body: Center(
        child: Card(
          elevation: 8,
          child: QrImageView(
            data: qrData,
            size: 250,
          ),
        ),
      ),

      /// 🍽 Menu
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const MenuDuJourSheet(),
          );
        },
        icon: const Icon(Icons.restaurant_menu),
        label: const Text("Menu du jour"),
      ),
    );
  }

  /// ==============================
  /// CLEANUP
  /// ==============================

  @override
  void dispose() {
    _timer?.cancel();
    supabase.removeChannel(_channel);
    super.dispose();
  }
}