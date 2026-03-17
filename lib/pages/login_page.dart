// ignore_for_file: use_build_context_synchronously
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/devices.dart';
import 'set_password_page.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService authService = AuthService();

  final TextEditingController matriculeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> handleLogin() async {
    final matricule = matriculeController.text.trim();
    final password = passwordController.text.trim();

    if (matricule.isEmpty || password.isEmpty) {
      showMessage("Veuillez remplir tous les champs");
      return;
    }

    if (password.length < 6) {
      showMessage("Le mot de passe doit avoir au moins 6 caractères");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await authService.login(matricule, password);

      if (result == null) {
        showMessage("Erreur inattendue");
        return;
      }

      final employee = result["employee"];

      if (employee == null) {
        showMessage("Utilisateur introuvable");
        return;
      }

      // 🔵 Si l'utilisateur doit définir un mot de passe
      if (result["needsPassword"] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetPasswordPage(employee: employee),
          ),
        );
        return;
      }

      // ✅ Sauvegarde de la session (TRÈS IMPORTANT)
      await context.read<SessionProvider>().saveSession(employee);

      // ⚠️ PAS DE NAVIGATION ICI
      // main.dart va détecter la session et rediriger automatiquement
      final deviceService = DeviceService();
        await deviceService.upsertDevice(
          supabase: Supabase.instance.client,
          employeeMatricule: employee['matricule'],
        );

    } catch (e) {
      showMessage("Erreur : ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    matriculeController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              body: Stack(
                children: [

                  // Cadre bleu de fond
                  Center(
                    child: Container(
                      width: 300,
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                  // Formulaire
                  Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // Image au-dessus du formulaire
                              Image.asset(
                                "assets/icons/icon_app_lunch.png",
                                height: 100,
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "Connexion",
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.black,
                                    ),
                              ),

                              const SizedBox(height: 10),

                              // Matricule
                              TextField(
                                controller: matriculeController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: "Matricule",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.badge),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Mot de passe
                              TextField(
                                controller: passwordController,
                                obscureText: !passwordVisible,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
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

                              const SizedBox(height: 25),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          "Se connecter",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}