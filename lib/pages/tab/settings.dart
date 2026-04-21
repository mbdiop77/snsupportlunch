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

  String role = 'restaurant';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadAdmins();
    listenToChanges();
  }

  Future<void> loadAdmins() async {
    final data = await supabase
        .from('employees')
        .select('email, prenom, role')
        .or('role.eq.admin,role.eq.subadmin')
        .order('prenom');

    if (!mounted) return;

    setState(() {
      admins = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  void listenToChanges() {
    supabase.channel('employees_channel').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (payload) => loadAdmins(),
    ).subscribe();
  }

  bool isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  Future<void> addAdmin() async {
    final email = emailController.text.trim();
    final prenom = prenomController.text.trim();

    if (prenom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full name obligatoire")),
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

    /// ✅ CORRECTION ICI (BON ENDROIT)
    final filteredAdmins = admins
        .where((admin) =>
            admin['role'] == 'admin' ||
            admin['role'] == 'subadmin')
        .toList();

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

                  /// FORMULAIRE
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          TextField(
                            controller: prenomController,
                            decoration:
                                const InputDecoration(labelText: 'Full name'),
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
                            decoration:
                                const InputDecoration(labelText: 'Rôle'),
                          ),

                          const SizedBox(height: 10),

                          ElevatedButton(
                            onPressed: isSubmitting ? null : addAdmin,
                            child: Text(
                                isSubmitting ? "Ajout..." : "Ajouter"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// LISTE ADMIN
                 Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: List.generate(filteredAdmins.length, (index) {
                              final admin = filteredAdmins[index];

                              final fullName = (admin['prenom'] ?? '').toString();
                              final roleText = (admin['role'] ?? '').toString();
                              final mail = (admin['email'] ?? '').toString();

                              Color roleColor;
                              switch (roleText) {
                                case 'admin':
                                  roleColor = Colors.red;
                                  break;
                                case 'subadmin':
                                  roleColor = Colors.orange;
                                  break;
                                default:
                                  roleColor = Colors.grey;
                              }

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;

                                  Widget roleEmail = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      /// ROLE
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          roleText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      /// EMAIL
                                      Text(
                                        mail,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  );

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: isMobile
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  /// TOP (ICON + NAME)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.admin_panel_settings,
                                                        size: 20,
                                                        color: Colors.blue,
                                                      ),
                                                      const SizedBox(width: 8),

                                                      Expanded(
                                                        child: Text(
                                                          fullName,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(height: 6),

                                                  /// BOTTOM (ROLE + EMAIL)
                                                  roleEmail,
                                                ],
                                              )
                                            : Row(
                                                children: [
                                                  /// LEFT
                                                  const Icon(
                                                    Icons.admin_panel_settings,
                                                    size: 20,
                                                    color: Colors.blue,
                                                  ),
                                                  const SizedBox(width: 8),

                                                  Expanded(
                                                    child: Text(
                                                      fullName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),

                                                  /// RIGHT (ROLE + EMAIL)
                                                  roleEmail,
                                                ],
                                              ),
                                      ),

                                      if (index != filteredAdmins.length - 1)
                                        const Divider(height: 1),
                                    ],
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
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