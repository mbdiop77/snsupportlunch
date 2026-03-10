import 'package:flutter/material.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  final Map employee;
  const AdminPage({super.key, required this.employee});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int selectedIndex = 0;

  int totalEmployees = 0;
  int mealsusedToday = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    final supabase = Supabase.instance.client;

    final employees = await supabase
    .from('employees')
    .select('id')
    .eq('role', 'employe');
    final mealsused = await supabase
        .from('employees')
        .select('id')
        .eq('used', true);
    // final meals = await supabase
      //  .from('employees')
      //  .select('id')
      //  .eq('used', true);


    setState(() {
      totalEmployees = employees.length;
      mealsusedToday = mealsused.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 20,
        backgroundColor:  Colors.blue,
        iconTheme: const IconThemeData(color: Colors.black),

        // MENU BUTTON MANUEL
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),

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
            Text(
              "${widget.employee['prenom']} ${widget.employee['nom']} (Admin)",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),

        actions: [
          // BADGE REPAS DU JOUR
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.restaurant, color: Colors.black),
                if (mealsusedToday > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      mealsusedToday.toString(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await context.read<SessionProvider>().logout();
            },
          ),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                "Administration",
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
          _drawerItem(Icons.dashboard, "Dashboard", 0),
          _drawerItem(Icons.people, "Employés", 1),
          _drawerItem(Icons.restaurant, "Historique repas", 2),
          _drawerItem(Icons.settings, "Paramètres", 3),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selectedIndex == index,
      onTap: () {
        setState(() => selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _statCard(
            title: "Employés",
            value: totalEmployees.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
          _statCard(
            title: "Repas pris aujourd'hui",
            value: mealsusedToday.toString(),
            icon: Icons.restaurant,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 15),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}