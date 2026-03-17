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
  late Timer _timer;
  String qrData = "";
  DateTime? weekStart;
  DateTime? weekEnd;

  @override
  void initState() {
    super.initState();
    generateQR();
    loadWeeklyMeals();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => generateQR());
  }

  void generateQR() {
    final matricule = widget.employee['matricule'];
    setState(() {
      qrData = QrService.generateQR(matricule);
      restants = 5 - (widget.employee['scan_number'] as int);
    });
  }

  Future<void> loadWeeklyMeals() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_user_week_meals',
        params: {'p_employee_id': widget.employee['id']},
      );
      final data = List<Map<String, dynamic>>.from(response);
      if (data.isNotEmpty) {
        setState(() {
          weekStart = DateTime.parse(data[0]['week_start']);
          weekEnd = DateTime.parse(data[0]['week_end']);
          restants = data[0]['remaining_meals'] ?? restants;
        });
      }
    } catch (e) {
      debugPrint("Erreur loadWeeklyMeals: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 20,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.person, color: Colors.black),
                padding: const EdgeInsets.all(1),
                constraints: const BoxConstraints(),
              ),
            ),
            Expanded(
              child: Text(
                "${widget.employee['prenom'] ?? ''}${(widget.employee['nom'] != null && widget.employee['nom'].toString().trim().isNotEmpty) ? ' ${widget.employee['nom']}' : ''}",
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              SuggestionDialog.show(context, (text) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Supabase.instance.client.from('comment').insert({
                    'comment_text': text,
                  });
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Merci pour votre suggestion 🙏")),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text("Erreur: $e")));
                }
              });
            },
          ),
         
          Tooltip(
             message: weekStart != null && weekEnd != null
                ? "Repas restant du  ${weekStart!.day}/${weekStart!.month} au ${weekEnd!.day}/${weekEnd!.month}"
                : "Semaine inconnue",
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.restaurant),
                if (restants >= 0)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      restants.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<SessionProvider>().logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Card(
          elevation: 8,
          child: QrImageView(
            data: qrData,
            size: 250,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const MenuDuJourSheet(),
          );
        },
        icon: const Icon(Icons.restaurant_menu),
        label: const Text("Menu du jour"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}