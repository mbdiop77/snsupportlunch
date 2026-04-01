// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'providers/session_provider.dart';
import 'guards/auth_guard.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart';
import 'pages/employe_page.dart';
import 'pages/restaurant_page.dart';
import 'services/auth_service.dart';
import 'services/devices.dart';

final SupabaseClient supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jilzolcigecrcvpaalbw.supabase.co', // Remplace par ton projet
    anonKey: 'jilzolcigecrcvpaalbw',               // Remplace par ta clé publique
  );

  final sessionProvider = SessionProvider();
  await sessionProvider.loadSession(); // charge la session si existante

  // 🔵 Écoute les changements d'état d'auth (Google SSO)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    if (session == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email == null) return;

    try {
      final result = await AuthService().loginWithGoogle();
      final employee = result?["employee"];
      if (employee != null) {
        await sessionProvider.saveSession(employee);

        // Upsert device pour suivi QR
        final deviceService = DeviceService();
        await deviceService.upsertDevice(
          supabase: Supabase.instance.client,
          employeeMatricule: employee['matricule'],
        );
      }
    } catch (e) {
     // print("Erreur récupération employé SSO: $e");
    }
  });

  runApp(
    ChangeNotifierProvider.value(
      value: sessionProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final authGuard = AuthGuard(session);

    final router = GoRouter(
      initialLocation: '/login',
      refreshListenable: session,
      redirect: (context, state) => authGuard.redirect(context, state),
      routes: [
        // Route racine redirige vers login
        GoRoute(path: '/', redirect: (_,_) => '/login'),

        // Login page (SSO)
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),

        // Admin page
        GoRoute(
          path: '/admin',
          builder: (context, state) => AdminPage(employee: session.employee!),
        ),

        // Employé page
        GoRoute(
          path: '/employe',
          builder: (context, state) => EmployePage(employee: session.employee!),
        ),

        // Restaurant page
        GoRoute(
          path: '/restaurant',
          builder: (context, state) => const RestaurantPage(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}