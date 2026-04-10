import 'dart:async';
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
  String searchQuery = '';

  int page = 0;
  final int limit = 20;
  bool hasMore = true;

  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadUsers(reset: true);
    setupRealtime();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        loadUsers();
      }
    });
  }

  /// ===========================
  /// LOAD USERS (PAGINATION + FILTER DB)
  /// ===========================
  Future<void> loadUsers({bool reset = false}) async {
    try {
      if (reset) {
        page = 0;
        users.clear();
        hasMore = true;
      }

      if (!hasMore) return;

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

      // filtre rôle
      if (selectedRole != 'all') {
        query = query.eq('role', selectedRole);
      }

      // recherche multi-colonnes
      if (searchQuery.isNotEmpty) {
        query = query.or(
          'matricule.ilike.%$searchQuery%,'
          'email.ilike.%$searchQuery%,'
          'prenom.ilike.%$searchQuery%,'
          'nom.ilike.%$searchQuery%',
        );
      }

      final response = await query
          .range(page * limit, (page + 1) * limit - 1);

      final newUsers = List<Map<String, dynamic>>.from(response);

      setState(() {
        users.addAll(newUsers);
        page++;
        isLoading = false;

        if (newUsers.length < limit) {
          hasMore = false;
        }
      });
    } catch (e) {
      debugPrint("ERROR loadUsers: $e");
    }
  }

  /// ===========================
  /// REALTIME
  /// ===========================
  void setupRealtime() {
    supabase
        .channel('realtime-users')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (_) {
            loadUsers(reset: true);
          },
        )
        .subscribe();
  }

  /// ===========================
  /// SEARCH DEBOUNCE
  /// ===========================
  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        searchQuery = value.toLowerCase();
      });
      loadUsers(reset: true);
    });
  }

  /// ===========================
  /// USER STATUS
  /// ===========================
  Future<void> toggleUserStatus(String matricule, String currentRole) async {
    final newRole =
        currentRole == 'disabled' ? 'restaurant' : 'disabled';

    await supabase
        .from('employees')
        .update({'role': newRole})
        .eq('matricule', matricule);

    loadUsers(reset: true);
  }

  /// ===========================
  /// DEVICE ACTIONS
  /// ===========================
  Future<void> disconnectDevice(String deviceId) async {
    await supabase
        .from('devices')
        .update({'is_active': false})
        .eq('device_id', deviceId);

    loadUsers(reset: true);
  }

  Future<void> deleteDevice(String deviceId) async {
    await supabase
        .from('devices')
        .delete()
        .eq('device_id', deviceId);

    loadUsers(reset: true);
  }

  /// ===========================
  /// ONLINE STATUS
  /// ===========================
  bool isUserOnline(List devices) {
    return devices.any((d) => d['is_active'] == true);
  }

  Widget buildStatusBadge(bool isOnline) {
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 10,
          color: isOnline ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 5),
        Text(isOnline ? "Online" : "Offline"),
      ],
    );
  }

  /// ===========================
  /// UI
  /// ===========================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: 900,
        height: 650,
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [

            /// HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Gestion des utilisateurs",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),

            const SizedBox(height: 10),

            /// SEARCH + FILTER
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Rechercher utilisateur...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("Tous")),
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'subadmin', child: Text("Sub Admin")),
                    DropdownMenuItem(value: 'restaurant', child: Text("Restaurant")),
                    DropdownMenuItem(value: 'disabled', child: Text("Disabled")),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                    loadUsers(reset: true);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// LIST
            Expanded(
              child: users.isEmpty && isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: users.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {

                        if (index >= users.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final user = users[index];
                        final devices = (user['devices'] ?? []) as List;

                        final isOnline = isUserOnline(devices);
                        final isDisabled = user['role'] == 'disabled';

                        final mainInfo =
                            (user['email'] != null && user['email'].toString().isNotEmpty)
                                ? user['email']
                                : "Matricule: ${user['matricule']}";

                        return Card(
                          color: isDisabled ? Colors.red.shade100 : null,
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: ExpansionTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${user['prenom']} ${user['nom']}"),
                                buildStatusBadge(isOnline),
                              ],
                            ),
                            subtitle: Text(mainInfo),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    /// ROLE + ACTION
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Role: ${user['role']}"),
                                        IconButton(
                                          icon: Icon(
                                            Icons.block,
                                            color: isDisabled
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          onPressed: () {
                                            toggleUserStatus(
                                                user['matricule'],
                                                user['role']);
                                          },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    /// DEVICES
                                    devices.isEmpty
                                        ? const Text("Aucun device")
                                        : Column(
                                            children: devices.map<Widget>((device) {
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(device['device_name'] ?? ''),
                                                  Text("Actif: ${device['is_active'] ? 'Oui' : 'Non'}"),
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.logout),
                                                        onPressed: () {
                                                          disconnectDevice(
                                                              device['device_id']);
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete),
                                                        onPressed: () {
                                                          deleteDevice(
                                                              device['device_id']);
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
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}