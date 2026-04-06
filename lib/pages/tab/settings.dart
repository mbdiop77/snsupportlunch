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

  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController matriculeController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController nomController = TextEditingController();

  String role = 'admin';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadAdmins();
    listenToChanges();
  }

  /// 🔄 Charger admins (AVEC sub_admin)
  Future<void> loadAdmins() async {
    final data = await supabase
        .from('employees')
        .select()
        .or('role.eq.admin,role.eq.sub_admin,role.eq.disabled')
        .order('prenom');

    if (!mounted) return;

    setState(() {
      admins = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  /// 🔄 Realtime
  void listenToChanges() {
    supabase.channel('employees_channel').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (payload) => loadAdmins(),
    ).subscribe();
  }

  /// ➕ Ajouter admin
  Future<void> addAdmin() async {
    if (matriculeController.text.trim().isEmpty ||
        prenomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Matricule et prénom obligatoires !")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await supabase.from('employees').insert({
        'email': emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(), // optionnel
        'matricule': matriculeController.text.trim(), // obligatoire
        'prenom': prenomController.text.trim(),
        'nom': nomController.text.trim().isEmpty
            ? null
            : nomController.text.trim(),
        'role': role,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajout réussi !")),
      );

      // reset
      emailController.clear();
      matriculeController.clear();
      prenomController.clear();
      nomController.clear();
      setState(() => role = 'admin');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }

    if (mounted) setState(() => isSubmitting = false);
  }

  /// 🔐 Logout via device
  Future<void> logoutAdmin(String matricule) async {
    try {
      await supabase
          .from('devices')
          .delete()
          .eq('employee_matricule', matricule);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Déconnecté !")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  /// ❌ Delete
  Future<void> deleteAdmin(String matricule) async {
    try {
      await supabase.from('employees').delete().eq('matricule', matricule);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Supprimé : $matricule")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  Future<void> confirmDelete(String matricule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmation"),
        content: Text("Supprimer $matricule ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer")),
        ],
      ),
    );

    if (confirm == true) deleteAdmin(matricule);
  }

  /// 🔁 Activer / désactiver
  Future<void> toggleAdmin(String matricule, String currentRole) async {
    try {
      final newRole = currentRole == 'disabled' ? 'admin' : 'disabled';

      await supabase
          .from('employees')
          .update({'role': newRole})
          .eq('matricule', matricule);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$matricule → $newRole")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  /// 🔒 Protection
  bool canModifyAdmin(Map admin,
      {bool forDelete = false, bool forLogout = false}) {
    final isCurrent =
        admin['matricule'] == widget.currentAdmin['matricule'];

    if (isCurrent && (forDelete || forLogout)) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentAdmin['role'] == 'admin';
    if (!isAdmin) { 

  if (!isAdmin) {
    return Scaffold(
     // appBar: AppBar(title: const Text("Paramètres")),
      body: const Center(
        child: Text(
          "Contenu inaccessible",
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      ),
    );
  }

  // Si admin, afficher le contenu normal
    }
    return Scaffold(
      appBar: AppBar(
  title: const Text("Gestion des Admins"),
  actions: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.people),
        label: const Text("Utilisateurs"),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              return const UsersManagementDialog();
            },
          );
        },
      ),
    ),
  ],
),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [

                  /// 🧾 FORMULAIRE
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [

                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                                labelText: 'Email'),
                          ),

                          TextField(
                            controller: matriculeController,
                            decoration: const InputDecoration(
                                labelText: 'Matricule *'),
                          ),

                          TextField(
                            controller: prenomController,
                            decoration: const InputDecoration(
                                labelText: 'Prénom *'),
                          ),

                          TextField(
                            controller: nomController,
                            decoration:
                                const InputDecoration(labelText: 'Nom'),
                          ),

                          const SizedBox(height: 5),

                          /// ✅ DROPDOWN AVEC SUB ADMIN
                          DropdownButtonFormField<String>(
                            initialValue: role,
                            items: const [
                              DropdownMenuItem(
                                  value: 'admin', child: Text('Admin')),
                              DropdownMenuItem(
                                  value: 'sub_admin',
                                  child: Text('Sub Admin')),
                              DropdownMenuItem(
                                  value: 'employe',
                                  child: Text('Employé')),
                              DropdownMenuItem(
                                  value: 'restaurant',
                                  child: Text('Restaurant')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => role = v);
                            },
                            decoration:
                                const InputDecoration(labelText: 'Rôle'),
                          ),

                          const SizedBox(height: 5),

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

                  /// 📋 LISTE (sans toList)
                  ...admins.map((admin) {
                    final fullName = [
                      admin['prenom'],
                      admin['nom']
                    ]
                        .where((e) =>
                            e != null &&
                            e.toString().trim().isNotEmpty)
                        .join(' ');

                    return ListTile(
                      title: Text(fullName),
                      subtitle:
                          Text("Matricule: ${admin['matricule']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.orange),
                            onPressed: canModifyAdmin(admin,
                                    forLogout: true)
                                ? () =>
                                    logoutAdmin(admin['matricule'])
                                : null,
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: canModifyAdmin(admin,
                                    forDelete: true)
                                ? () => confirmDelete(
                                    admin['matricule'])
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}