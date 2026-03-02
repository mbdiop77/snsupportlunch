// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

// Import de tes pages
import 'admin_page.dart';
import 'employe_page.dart';
import 'restaurant_page.dart';

class SetPasswordPage extends StatefulWidget {
  final Map<String, dynamic> employee;

  const SetPasswordPage({super.key, required this.employee});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  bool passwordVisible = false;

  Future<void> savePassword() async {
    final newPassword = passwordController.text.trim();

    if (newPassword.isEmpty) {
      showMessage("Veuillez entrer un mot de passe");
      return;
    }
    if (newPassword.length < 6) {
      showMessage("Le mot de passe doit avoir au moins 6 caractères");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Hash du mot de passe
      final hashed = sha256.convert(utf8.encode(newPassword)).toString();

      // Mise à jour dans Supabase
      await supabase
          .from('employees')
          .update({'password_hash': hashed})
          .eq('id', widget.employee['id']);

      // Mise à jour locale
      widget.employee['password_hash'] = hashed;

      // Sauvegarde de la session
      await context.read<SessionProvider>().saveSession(widget.employee);

      // Redirection directe selon le rôle
      final role = widget.employee['role'] as String?;
      Widget nextPage;

      switch (role) {
        case 'admin':
          nextPage = AdminPage(employee: widget.employee);
          break;
        case 'employe':
          nextPage = EmployePage(employee: widget.employee);
          break;
        case 'restaurant':
          nextPage = RestaurantPage();
          break;
        default:
          showMessage("Rôle inconnu");
          return;
      }

      // Remplace l'écran actuel
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    } catch (e) {
      showMessage("Erreur: ${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Veuillez confirmer votre mot de passe",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading ? null : savePassword,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Enregistrer"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}