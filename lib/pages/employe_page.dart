import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
import '../features/menu_du_jour_sheet.dart';
import '../features/suggestion_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    generateQR();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => generateQR(),
    );
  }

  void generateQR() {
    final matricule = widget.employee['matricule'];
    final timestamp =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final secretKey = "WAVE_SECRET_KEY";

    final rawData = "$matricule|$timestamp";
    final signature = sha256
        .convert(utf8.encode(rawData + secretKey))
        .toString()
        .substring(0, 15);

    setState(() {
      qrData = "$timestamp$matricule$signature";
       restants = 5- widget.employee['scan_number'] as int ;

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      elevation: 20,backgroundColor: Colors.white ,
      automaticallyImplyLeading: false,
  centerTitle: false, // IMPORTANT
  title: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
  decoration: const BoxDecoration(
    color: Colors.grey, // couleur du fond
    shape: BoxShape.circle,
  ),
  
  child: IconButton(
    onPressed: () {},
    icon: const Icon(
      Icons.person_2_rounded,
      color: Colors.black, // couleur de l’icône
    ),
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(),
  ),
),
   //   const SizedBox(width: 8),
      Expanded(
        child: Text(
          "${widget.employee['prenom'] ?? ''} ${widget.employee['nom'] ?? ''}",
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
                  await Supabase.instance.client
                      .from('comment')
                      .insert({
                    'comment_text': text,
                  });

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Merci pour votre suggestion 🙏"),
                    ),
                  );

                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text("Erreur: $e")),
                  );
                }
              });
            },
          ),
              Tooltip(
                message: "Semaine ${widget.employee['week_number']}",
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.black),

                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.employee['week_number'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                      //  const SizedBox(width: 20), 
              Tooltip(
                  message: "Plats restants pour la sem ${widget.employee['week_number']}",
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
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
          elevation : 08,
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
        isScrollControlled: true, // permet de faire un DraggableScrollableSheet
        backgroundColor: Colors.transparent, // pour les coins arrondis si tu veux
        builder: (context) => const MenuDuJourSheet(), // <-- ton widget importé
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