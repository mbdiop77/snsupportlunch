import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersManagementDialog extends StatefulWidget {
  const UsersManagementDialog({super.key});

  @override
  State<UsersManagementDialog> createState() =>
      _UsersManagementDialogState();
}

class _UsersManagementDialogState extends State<UsersManagementDialog> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    loadUsers();
    setupRealtime();
  }

  /// ===========================
  /// FETCH USERS + DEVICES
  /// ===========================
Future<void> loadUsers() async {
  try {
    setState(() => isLoading = true);

    var query = supabase.from('employees').select('''
      matricule,
      prenom,
      nom,
      email,
      role,
      devices (
        device_id,
        last_seen,
        device_name,
        is_active
      )
    ''');

    // 🔹 Filtre par rôle sauf "all"
    if (selectedRole != 'all') {
      query = query.eq('role', selectedRole.trim());
    }

    final response = await query;

    //debugPrint("ROLE SELECTED: $selectedRole");

    setState(() {
      users = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  } catch (e) {
    debugPrint("ERROR: $e");
  }

  // 🔹 DEBUG : afficher les rôles récupérés
}

  /// ===========================
  /// REALTIME (AUTO REFRESH)
  /// ===========================
  void setupRealtime() {
    supabase
        .channel('public:devices')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (payload) {
            loadUsers();
          },
        )
        .subscribe();
  }

  /// ===========================
  /// ACTIONS
  /// ===========================

  Future<void> disconnectDevice(String deviceId) async {
    await supabase
        .from('devices')
        .update({'is_active': false})
        .eq('device_id', deviceId);

    loadUsers();
  }

  Future<void> toggleDevice(String deviceId, bool status) async {
    await supabase
        .from('devices')
        .update({'is_active': status})
        .eq('device_id', deviceId);

    loadUsers();
  }

/// ===========================
/// LOGOUT ALL USERS (FORCE)
/// ===========================
Future<void> _logoutAllUsers() async {
  try {
    // 1️⃣ Récupère tous les devices
    for (var user in users) {
      final devicesRaw = user['devices'];
      final List devices = devicesRaw is List
          ? devicesRaw
          : devicesRaw != null
              ? [devicesRaw]
              : [];

      for (var device in devices) {
              debugPrint("debug test log out id device : ${device['device_id']}");

        // 2️⃣ Met à jour is_active = false
        await supabase
            .from('devices')
            .update({'is_active': false})
            .eq('device_id', device['device_id']);
      }
    }

    // 3️⃣ Affiche SnackBar après mise à jour DB
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tous les utilisateurs ont été déconnectés !"),
      ),
    );
  } catch (e) {
    debugPrint("Erreur logoutAllUsers: $e");
  }
}

Future<void> _deleteAllUsers(BuildContext ctx) async {
  for (var user in users) {
    final devicesRaw = user['devices'];
    final List devices = devicesRaw is List
        ? devicesRaw
        : devicesRaw != null
            ? [devicesRaw]
            : [];
    for (var device in devices) {
      await deleteDevice(device['device_id']);
    }
  }
    if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Tous les utilisateurs ont été supprimés")),
  );
}
  Future<void> deleteDevice(String deviceId) async {
    await supabase
        .from('devices')
        .delete()
        .eq('device_id', deviceId);

    loadUsers();
  }

  /// ===========================
  /// UI
  /// ===========================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(5),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [

           /// HEADER
/// HEADER SAFE
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      "Gestion des utilisateurs",
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    Row(
      children: [
        // 🔹 Logout All
        IconButton(
          tooltip: "Déconnecter tous",
          icon: const Icon(Icons.logout),
          onPressed: () {
            showDialog<bool>(
              context: context,
              builder: (BuildContext ctx) {
                return AlertDialog(
                  title: const Text("Confirmer"),
                  content: const Text("Déconnecter tous les utilisateurs ?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Annuler"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true);
                        _logoutAllUsers(); // tout safe ici
                      },
                      child: const Text("Oui"),
                    ),
                  ],
                );
              },
            );
          },
        ),

        // 🔹 Delete All
        IconButton(
          tooltip: "Supprimer tous",
          icon: const Icon(Icons.delete),
          onPressed: () {
            showDialog<bool>(
              context: context,
              builder: (BuildContext ctx) {
                return AlertDialog(
                  title: const Text("Confirmer"),
                  content: const Text("Supprimer tous les utilisateurs ?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Annuler"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true);
                        _deleteAllUsers(ctx); // tout safe ici
                      },
                      child: const Text("Oui"),
                    ),
                  ],
                );
              },
            );
          },
        ),

        // 🔹 Close
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    ),
  ],
),
// FIN HEADER

            const SizedBox(height: 10),

            /// FILTRE ROLE
            Row(
              children: [
                const Text("Filtrer par rôle: "),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("Tous")),
                    DropdownMenuItem(value: 'admin', child: Text("Admin (root)")),
                    DropdownMenuItem(value: 'subadmin', child: Text("Sub Admin")),
                    DropdownMenuItem(value: 'restaurant', child: Text("Restaurant")),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                    loadUsers();
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// LISTE
           Expanded(
  child: isLoading
      ? const Center(child: CircularProgressIndicator())
      : users.isEmpty
          ? const Center(child: Text("Aucun utilisateur"))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final devicesRaw = user['devices'];
                final List devices = devicesRaw is List
                    ? devicesRaw
                    : devicesRaw != null
                        ? [devicesRaw]
                        : [];

                // Pour restaurant : pas d'email → afficher matricule
                final String mainInfo = (user['email'] != null && user['email'].toString().isNotEmpty)
                    ? user['email']
                    : "Matricule: ${user['matricule']}";

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ExpansionTile(
                    title: Text(
                      "${user['prenom']} ${user['nom']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(mainInfo),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Rôle
                            Text("Role: ${user['role']}"),
                            const SizedBox(height: 8),

                            // Devices
                            devices.isEmpty
                                ? const Text("Aucun device")
                                : Column(
                                    children: devices.map<Widget>((device) {
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Device: ${device['device_name']}"),
                                          Text("Last seen: ${device['last_seen'] ?? 'N/A'}"),
                                          Text("Actif: ${device['is_active'] == true ? 'Oui' : 'Non'}"),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.logout),
                                                onPressed: () {
                                                  disconnectDevice(device['device_id']);
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () {
                                                  deleteDevice(device['device_id']);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
           )
          ],
        ),
      ),
    );
  }
}

