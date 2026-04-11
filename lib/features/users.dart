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

  /// 🔥 DEFAULT = employee
  String selectedRole = 'employe';
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

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        loadUsers();
      }
    });
  }

  /// ===========================
  /// LOAD USERS (CLEAN VERSION)
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

      var query = supabase
          .from('employees')
          .select('matricule, prenom, nom, email, role, status');

      /// ✅ filtre ROLE (OBLIGATOIRE)
      query = query.eq('role', selectedRole);

      /// ✅ SEARCH SAFE
      if (searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim();

        query = query.or(
          'matricule.ilike.%$search%,'
          'email.ilike.%$search%,'
          'prenom.ilike.%$search%,'
          'nom.ilike.%$search%',
        );
      }

      final response = await query
          .range(page * limit, (page + 1) * limit - 1);

      final newUsers = List<Map<String, dynamic>>.from(response);

      setState(() {
        users.addAll(newUsers);
        page++;
        isLoading = false;
        hasMore = newUsers.length == limit;
      });
    } catch (e) {
      debugPrint("ERROR loadUsers: $e");
    }
  }

  /// ===========================
  /// SEARCH DEBOUNCE
  /// ===========================
  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => searchQuery = value.toLowerCase());
      loadUsers(reset: true);
    });
  }

  /// ===========================
  /// STATUS USER
  /// ===========================
  Future<void> toggleUserStatus(String matricule, bool currentStatus) async {
    await supabase
        .from('employees')
        .update({'status': !currentStatus})
        .eq('matricule', matricule);

    loadUsers(reset: true);
  }

  /// ===========================
  /// UI
  /// ===========================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 850,
        height: 600,
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

            /// SEARCH + ROLE FILTER
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Rechercher (matricule, email, nom...)",
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
                    DropdownMenuItem(value: 'employe', child: Text("Employes")),
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'subadmin', child: Text("Sub Admin")),
                    DropdownMenuItem(value: 'restaurant', child: Text("Restaurant")),
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
                  : users.isEmpty
                      ? const Center(child: Text("Aucun utilisateur"))
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
                            final isActive = user['status'] == true;

                            final mainInfo =
                                (user['email'] != null &&
                                        user['email'].toString().isNotEmpty)
                                    ? user['email']
                                    : "Matricule: ${user['matricule']}";

                            return Card(
                              color: isActive ? null : Colors.red.shade100,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              child: ListTile(
                                title: Text(
                                  "${user['prenom']} ${user['nom']}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(mainInfo),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isActive ? "Actif" : "Bloqué",
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.block,
                                        color: isActive
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      onPressed: () {
                                        toggleUserStatus(
                                          user['matricule'],
                                          isActive,
                                        );
                                      },
                                    ),
                                  ],
                                ),
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