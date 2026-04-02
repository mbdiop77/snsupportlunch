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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jilzolcigecrcvpaalbw.supabase.co',
    anonKey: 'jilzolcigecrcvpaalbw', // 🔥 mets la vraie clé
  );

  final sessionProvider = SessionProvider();
  await sessionProvider.loadSession();

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
      redirect: (context, state) =>
          authGuard.redirect(context, state),

      routes: [
        GoRoute(path: '/', redirect: (_,_) => '/login'),

        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),

        GoRoute(
          path: '/admin',
          builder: (context, state) =>
              AdminPage(employee: session.employee!),
        ),

        GoRoute(
          path: '/employe',
          builder: (context, state) =>
              EmployePage(employee: session.employee!),
        ),

        GoRoute(
          path: '/restaurant',
          builder: (context, state) =>
              const RestaurantPage(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}