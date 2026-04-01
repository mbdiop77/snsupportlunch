// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/devices.dart';
import '../providers/session_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false;
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    authService = AuthService();

    // 🔹 Listener pour le retour de Google SSO
    authService.supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) return; // pas connecté

      try {
        if (mounted) setState(() => isLoading = true);

        // Récupère l'employé connecté
        final result = await authService.loginWithGoogle();
        final employee = result?["employee"];

        if (employee != null && mounted) {
          final sessionProvider =
              Provider.of<SessionProvider>(context, listen: false);
          await sessionProvider.saveSession(employee);

          // 🔹 Upsert device
          final deviceService = DeviceService();
          await deviceService.upsertDevice(
            supabase: authService.supabase,
            employeeMatricule: employee['matricule'],
          );

          // 🔹 Redirection selon rôle
          _redirectByRole(employee['role']);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur login Google : $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  // 🔹 Redirection selon rôle
  void _redirectByRole(String role) {
    switch (role) {
      case 'admin':
        context.go('/admin');
        break;
      case 'employe':
        context.go('/employe');
        break;
      case 'restaurant':
        context.go('/restaurant');
        break;
      default:
        context.go('/login');
    }
  }

  // 🔹 Déclenche Google SSO
  Future<void> _loginWithGoogle() async {
    if (mounted) setState(() => isLoading = true);
    try {
      await authService.signInWithGoogle(
        redirectTo: 'https://snsupport-lunch.netlify.app',
      );
      // ⚠ Pas besoin de récupérer l'utilisateur ici
      // C'est géré par le listener onAuthStateChange
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur login Google : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 400 ? screenWidth : 360,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔹 Logo / image app
                Image.asset(
                  "assets/icons/icon_app_lunch.png",
                  height: 90,
                ),
                const SizedBox(height: 32),

                // 🔹 Texte explicatif
                const Text(
                  "Bienvenue !\nVeuillez vous connecter avec votre compte professionnel",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),

                // 🔹 Bouton Google SSO
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _loginWithGoogle,
                          icon: Image.asset(
                            "assets/icons/google_logo.png",
                            height: 24,
                            width: 24,
                          ),
                          label: const Text(
                            "Se connecter avec Google",
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}