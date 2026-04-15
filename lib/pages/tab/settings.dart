import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/users.dart';

class SettingPage extends StatefulWidget {
  final Map currentAdmin;
  const SettingPage({super.key, required this.currentAdmin});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> admins = [];
  bool isLoading = true;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();

  String role = 'admin';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadAdmins();
    listenToChanges();
  }

  /// ===========================
  /// LOAD ADMINS
  /// ===========================
  Future<void> loadAdmins() async {
    final data = await supabase
        .from('employees')
        .select('email, prenom, role')
        .or('role.eq.admin,role.eq.subadmin,role.eq.employe,role.eq.restaurant')
        .order('prenom');

    if (!mounted) return;

    setState(() {
      admins = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  /// ===========================
  /// REALTIME
  /// ===========================
  void listenToChanges() {
    supabase.channel('employees_channel').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (payload) => loadAdmins(),
    ).subscribe();
  }

  /// ===========================
  /// EMAIL VALIDATION
  /// ===========================
  bool isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  /// ===========================
  /// ADD USER
  /// ===========================
  Future<void> addAdmin() async {
    final email = emailController.text.trim();
    final prenom = prenomController.text.trim();

    /// 🔐 VALIDATION
    if (email.isEmpty || prenom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Email et full name sont obligatoires")),
      );
      return;
    }

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email invalide")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await supabase.from('employees').insert({
        'email': email,
        'prenom': prenom,
        'role': role,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur ajouté")),
      );

      emailController.clear();
      prenomController.clear();

      setState(() => role = 'admin');
      loadAdmins();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }

    if (mounted) setState(() => isSubmitting = false);
  }

  /// ===========================
  /// UI
  /// ===========================
  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentAdmin['role'] == 'admin';

    if (!isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Contenu inaccessible",
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des utilisateurs"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text("Utilisateurs"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const UsersManagementDialog(),
                );
              },
            ),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [

                  /// ===========================
                  /// FORMULAIRE
                  /// ===========================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [

                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),

                          TextField(
                            controller: prenomController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                            ),
                          ),

                          const SizedBox(height: 10),

                          DropdownButtonFormField<String>(
                            initialValue: role,
                            items: const [
                              DropdownMenuItem(
                                  value: 'restaurant',
                                  child: Text('Restaurant')),
                              DropdownMenuItem(
                                  value: 'admin', child: Text('Admin')),
                              DropdownMenuItem(
                                  value: 'subadmin',
                                  child: Text('Sub Admin')),
                              DropdownMenuItem(
                                  value: 'employe',
                                  child: Text('Employe')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => role = v);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Rôle',
                            ),
                          ),

                          const SizedBox(height: 10),

                          ElevatedButton(
                            onPressed: isSubmitting ? null : addAdmin,
                            child: Text(
                              isSubmitting ? "Ajout..." : "Ajouter",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// ===========================
                  /// LISTE UTILISATEURS
                  /// ===========================
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: admins.map((admin) {
                          final fullName = (admin['prenom'] ?? '').toString();
                          final roleText = (admin['role'] ?? '').toString();

                          final displayName =
                              "$fullName ${roleText.isNotEmpty ? '($roleText)' : ''}";

                          return ListTile(
                            title: Text(displayName),
                            subtitle: Text(admin['email'] ?? ''),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    prenomController.dispose();
    super.dispose();
  }
}