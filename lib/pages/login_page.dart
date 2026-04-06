// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  late final StreamSubscription<AuthState> authListener;

  @override
  void initState() {
    super.initState();

    authService = AuthService();

    /// 🔥 LISTENER SSO
    authListener = authService.supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      debugPrint("EVENT: $event");

      if (event != AuthChangeEvent.signedIn || session == null) return;

      try {
        if (mounted) setState(() => isLoading = true);

        final user = authService.supabase.auth.currentUser;
        debugPrint("USER EMAIL: ${user?.email}");

        // 🔥 Récupération employé depuis DB
        final result = await authService.loginWithGoogle(); // Ta fonction doit retourner employee
        final employee = result?["employee"];

        if (employee == null) {
          throw Exception("Utilisateur non autorisé");
        }

        // 🔥 Sauvegarde session locale
        final sessionProvider = context.read<SessionProvider>();
        await sessionProvider.saveSession(employee);

        // 🔥 Device tracking
        final deviceService = DeviceService();
        await deviceService.upsertDevice(
          supabase: authService.supabase,
          employeeMatricule: employee['matricule'],
        );

        // 🔥 REDIRECTION
        _redirectByRole(employee['role']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur : $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  /// 🔥 Redirection selon rôle
  void _redirectByRole(String role) {
    switch (role) {
      case 'admin':
      case 'subadmin': 
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

  /// 🔥 Lancer SSO Google
  Future<void> _loginWithGoogle() async {
    try {
      if (mounted) setState(() => isLoading = true);

      await authService.signInWithGoogle(
        redirectTo: 'http://localhost:3000', // 🔥 URL locale
      );

      // ⚠️ Le listener gère tout
    } catch (e) {
      debugPrint("ERREUR SSO: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur login Google")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    authListener.cancel(); // 🔥 éviter fuite mémoire
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width < 400 ? width : 360,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// 🔹 Logo app
                Image.asset(
                  "assets/icons/icon_app_lunch.png",
                  height: 100,
                ),
                const SizedBox(height: 30),

                /// 🔹 Texte
                const Text(
                  "Bienvenue 👋\nConnectez-vous avec votre compte professionnel",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),

                /// 🔹 Bouton Google
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _loginWithGoogle,
                          icon: Image.asset(
                            "assets/icons/google_logo.png",
                            height: 22,
                          ),
                          label: const Text(
                            "Se connecter avec Google",
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 15),

                /// 🔹 Loader texte
                if (isLoading)
                  const Text(
                    "Connexion en cours...",
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}