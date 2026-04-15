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

  String selectedRole = 'employe';
  String searchQuery = '';

  int page = 0;
  final int limit = 20;
  bool hasMore = true;

  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  final List<String> roles = [
    'employe',
    'admin',
    'subadmin',
    'restaurant'
  ];

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
  /// LOAD USERS
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
          .select('prenom, email, role, status');

      query = query.eq('role', selectedRole);

      if (searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim();

        query = query.or(
          'email.ilike.%$search%,'
          'prenom.ilike.%$search%',
        );
      }

      final response = await query.range(
        page * limit,
        (page + 1) * limit - 1,
      );

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
  /// SEARCH
  /// ===========================
  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => searchQuery = value.toLowerCase());
      loadUsers(reset: true);
    });
  }

  /// ===========================
  /// TOGGLE STATUS (FIXED)
  /// ===========================
  Future<void> toggleUserStatus(String email, bool currentStatus) async {
    await supabase
        .from('employees')
        .update({'status': !currentStatus})
        .eq('email', email);

    loadUsers(reset: true);
  }

  /// ===========================
  /// UPDATE ROLE
  /// ===========================
  Future<void> updateUserRole(String email, String newRole) async {
    await supabase
        .from('employees')
        .update({'role': newRole})
        .eq('email', email);

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
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
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
                      hintText: "Rechercher (email, prénom)",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),

                DropdownButton<String>(
                  value: selectedRole,
                  items: roles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ))
                      .toList(),
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
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }

                            final user = users[index];
                            final isActive = user['status'] == true;

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile =
                                    constraints.maxWidth < 600;

                                return SizedBox(
                                  width: double.infinity,
                                  child: Card(
                                    color: isActive
                                        ? null
                                        : Colors.red.shade100,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10),
                                      child: isMobile
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  user['prenom'] ?? '',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .bold),
                                                ),
                                                Text(
                                                  user['email'] ?? '',
                                                  style: const TextStyle(
                                                      color:
                                                          Colors.grey),
                                                ),
                                                const SizedBox(
                                                    height: 10),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    DropdownButton<
                                                        String>(
                                                      value:
                                                          user['role'],
                                                      items: roles
                                                          .map((r) =>
                                                              DropdownMenuItem(
                                                                value: r,
                                                                child: Text(
                                                                    r),
                                                              ))
                                                          .toList(),
                                                      onChanged:
                                                          (newRole) {
                                                        if (newRole !=
                                                            null) {
                                                          updateUserRole(
                                                            user[
                                                                'email'],
                                                            newRole,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    Text(
                                                      isActive
                                                          ? "Actif"
                                                          : "Bloqué",
                                                      style: TextStyle(
                                                        color: isActive
                                                            ? Colors
                                                                .green
                                                            : Colors.red,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.block,
                                                        color: isActive
                                                            ? Colors.red
                                                            : Colors
                                                                .green,
                                                      ),
                                                      onPressed: () {
                                                        toggleUserStatus(
                                                          user['email'],
                                                          isActive,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )

                                          /// DESKTOP
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user['prenom'] ??
                                                            '',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      Text(
                                                        user['email'] ??
                                                            '',
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .grey),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    DropdownButton<
                                                        String>(
                                                      value:
                                                          user['role'],
                                                      items: roles
                                                          .map((r) =>
                                                              DropdownMenuItem(
                                                                value: r,
                                                                child: Text(
                                                                    r),
                                                              ))
                                                          .toList(),
                                                      onChanged:
                                                          (newRole) {
                                                        if (newRole !=
                                                            null) {
                                                          updateUserRole(
                                                            user[
                                                                'email'],
                                                            newRole,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    const SizedBox(
                                                        width: 10),
                                                    Text(
                                                      isActive
                                                          ? "Actif"
                                                          : "Bloqué",
                                                      style: TextStyle(
                                                        color: isActive
                                                            ? Colors
                                                                .green
                                                            : Colors.red,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.block,
                                                        color: isActive
                                                            ? Colors.red
                                                            : Colors
                                                                .green,
                                                      ),
                                                      onPressed: () {
                                                        toggleUserStatus(
                                                          user['email'],
                                                          isActive,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              },
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