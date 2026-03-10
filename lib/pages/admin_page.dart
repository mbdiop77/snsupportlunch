import 'package:flutter/material.dart';
import 'tab/dashboardpage.dart';
import 'tab/weeklywenuadmin.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'tab/affiche_suggestions.dart';
import 'tab/history.dart';
class AdminPage extends StatefulWidget {
  final Map employee;

  const AdminPage({super.key, required this.employee});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // nombre d'onglets
      child: Scaffold( 
       appBar: AppBar(
        elevation: 20,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.person_2_rounded, color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
             Expanded(
              child: Text(
                "${widget.employee['prenom']} ${widget.employee['nom']} (Admin)",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await context.read<SessionProvider>().logout();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              Container(height: 5, color: Colors.white),
              const TabBar(
                labelStyle: TextStyle(fontSize: 12),
                tabs: [
                  Tab(icon: Icon(Icons.dashboard, size: 18), text: "Dashboard"),
                  Tab(icon: Icon(Icons.calendar_month, size: 18), text: "Planification du menu"),
                  Tab(icon: Icon(Icons.history, size: 18), text: "Historique"),
                  Tab(icon: Icon(Icons.message, size: 18), text: "Susggestion"),
                  Tab(icon: Icon(Icons.person, size: 18), text: "Profil"),
                ],
              ),
            ],
          ),
        ),
              ),
        body: const TabBarView(
          children: [
            Center(child: DashboardPage()),
            Center(child: WeeklyMenuAdmin()),
            Center(child: HistoryPage()),
            Center(child: SuggestionsPage()),
            Center(child: Text("Page Profil")),
          ],
        ),
      ),
    );
  }
}