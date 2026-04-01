import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Form controllers
  final TextEditingController matriculeController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  String role = 'employe';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadAdmins();
    listenToChanges();
  }

  /// Charger la liste des admins
  Future<void> loadAdmins() async {
    final data = await supabase
        .from('employees')
        .select()
        .or('role.eq.admin,role.eq.disabled')
        .order('prenom');
    if (!mounted) return;

    setState(() {
      admins = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  /// Écoute en temps réel
  void listenToChanges() {
    supabase.channel('employees_channel').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (payload) => loadAdmins(),
    ).subscribe();
  }

  /// Ajouter un admin
  Future<void> addAdmin() async {
    if (matriculeController.text.isEmpty || prenomController.text.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      await supabase.from('employees').insert({
        'matricule': matriculeController.text.trim(),
        'prenom': prenomController.text.trim(),
        'role': role,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfull !")));
    } catch (e) {
      if (!mounted) return;
      final matricule = matriculeController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Le matricule $matricule existe déjà, merci de vérifier les informations saisies."),
        ),
      );
    }

    if (mounted) setState(() => isSubmitting = false);
  }

  /// Déconnecter un admin
  Future<void> logoutAdmin(String matricule) async {
    try {
      await supabase.from('devices').delete().eq('employee_matricule', matricule);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Admin déconnecté !")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur logout : $e")));
    }
  }

  /// Supprimer un admin
  Future<void> deleteAdmin(String matricule) async {
    try {
      await supabase.from('employees').delete().eq('matricule', matricule);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Admin $matricule supprimé !")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur delete : $e")));
    }
  }

  /// Confirmation suppression
  Future<void> confirmDelete(String matricule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmation"),
        content: Text("Voulez-vous supprimer l'utilisateur $matricule ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm == true) deleteAdmin(matricule);
  }

  /// Désactiver / réactiver un admin
  Future<void> toggleAdmin(String matricule, String currentRole) async {
    try {
      final newRole = currentRole == 'admin' ? 'disabled' : 'admin';
      await supabase
          .from('employees')
          .update({'role': newRole})
          .eq('matricule', matricule);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("User $matricule is $newRole")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  /// Vérifie si un admin peut effectuer une action
  bool canModifyAdmin(Map admin,
      {bool forDelete = false, bool forDisable = false, bool forLogout = false}) {
    final isCurrent = admin['matricule'] == widget.currentAdmin['matricule'];

    // Admin courant ne peut pas supprimer, désactiver ou déconnecter lui-même
    if (isCurrent && (forDelete || forDisable || forLogout)) return false;

    return true; // tout le reste autorisé
  }

  @override
  Widget build(BuildContext context) {
    final currentName = widget.currentAdmin['nom']?.toString().trim();
   // final screenWidth = MediaQuery.of(context).size.width;
   // final isWide = screenWidth >= 700;

    // Si le nom de l'admin courant est vide ou null → page inaccessible
    if (currentName == null || currentName.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            "contenu inaccessible",
            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // TITRE FIXE
          Container(
            width: double.infinity,
            height: 30,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Text(
              "Gestion des Admins",
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Formulaire ajout
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: matriculeController,
                                  decoration:
                                      const InputDecoration(labelText: 'Matricule'),
                                ),
                                const SizedBox(height: 05),
                                TextField(
                                  controller: prenomController,
                                  decoration:
                                      const InputDecoration(labelText: 'Full name'),
                                ),
                                const SizedBox(height: 05),
                                DropdownButtonFormField<String>(
                                  initialValue: role,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'admin', child: Text('Admin')),
                                    
                                        DropdownMenuItem(
                                        value: 'restaurant', child: Text('Restaurant')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => role = v);
                                  },
                                  decoration:
                                      const InputDecoration(labelText: 'Rôle'),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add),
                                  label: Text(isSubmitting ? "Ajout..." : "Ajouter"),
                                  style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50)),
                                  onPressed: isSubmitting ? null : addAdmin,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Liste admins
                       
                       Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 450, // largeur maximale de la card
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: admins.map((admin) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [

                                            // 🔹 Matricule
                                            SizedBox(
                                              width: 40,
                                              child: Text(admin['matricule'] ?? ''),
                                            ),

                                            const SizedBox(width: 2),

                                            // 🔹 Nom + prénom
                                            Expanded(
                                              child: Text(
                                                "${admin['prenom'] ?? ''}${(admin['nom'] != null && admin['nom'].toString().trim().isNotEmpty) ? ' ${admin['nom']}' : ''}",
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),

                                            // 🔹 Role
                                            SizedBox(
                                              width: 55,
                                              child: Text(admin['role'] ?? ''),
                                            ),

                                            // 🔹 Disable
                                            IconButton(
                                              icon: Icon(
                                                admin['role'] == 'disabled'
                                                    ? Icons.block
                                                    : Icons.check_circle,
                                                color: admin['role'] == 'disabled'
                                                    ? Colors.blueGrey
                                                    : Colors.green,
                                              ),
                                              onPressed: canModifyAdmin(admin, forDisable: true)
                                                  ? () => toggleAdmin(
                                                      admin['matricule'] ?? '',
                                                      admin['role'] ?? '')
                                                  : null,
                                            ),

                                            // 🔹 Logout
                                            IconButton(
                                              icon: const Icon(Icons.logout, color: Colors.orange),
                                              onPressed: canModifyAdmin(admin, forLogout: true)
                                                  ? () => logoutAdmin(admin['matricule'] ?? '')
                                                  : null,
                                            ),

                                            // 🔹 Delete
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: canModifyAdmin(admin, forDelete: true)
                                                  ? () => confirmDelete(admin['matricule'] ?? '')
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}