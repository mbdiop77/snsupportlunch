import 'package:flutter/material.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
class AdminPage extends StatefulWidget {
  final Map<String, dynamic> employee;
  const AdminPage({super.key, required this.employee});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
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
      const SizedBox(width: 1),
      Text(
        "${widget.employee['prenom'] ?? ''} ${widget.employee['nom'] ?? ''}(admin)",
        style: const TextStyle(fontSize: 16),
      ),
    ],
  ),
  actions: [
     IconButton(
      icon: const Icon(Icons.person_add),
      onPressed: () async {
      },
    ),
   
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await context.read<SessionProvider>().logout();
      },
    ),
  ],
      ),
    );
  }
}