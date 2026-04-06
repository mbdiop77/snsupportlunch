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
//import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'services/device_realtime.dart';
//import 'services/devices.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://jilzolcigecrcvpaalbw.supabase.co',
    anonKey: 'sb_publishable_Ss7RrwL2LCFuctkCX8YabA_fWjQ8oBE',
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
          builder: (context, state) => session.employee != null
    ? AdminPage(employee: session.employee!)
    : const LoginPage(),
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


