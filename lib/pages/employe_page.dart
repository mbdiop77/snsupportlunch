import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';

class EmployePage extends StatefulWidget {
final Map<String, dynamic> employee;
  const EmployePage({super.key, required this.employee});

  @override
  State<EmployePage> createState() => _DynamicQRState();
}

class _DynamicQRState extends State<EmployePage> {
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
      Text(
        "${widget.employee['prenom'] ?? ''} ${widget.employee['nom'] ?? ''}",
        style: const TextStyle(fontSize: 16),
      ),
    ],
  ),
       actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            color: Colors.black,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_rounded),
            color: Colors.black,
            onPressed: () { },
          ),
        //  const SizedBox(width: 20), 
  
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
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}