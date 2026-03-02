import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/session_provider.dart';

class AuthGuard {
  final SessionProvider session;

  AuthGuard(this.session);

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path; // ⚡ utilise uri.path au lieu de location

    // Non connecté → login
    if (!session.isLoggedIn && path != '/login') return '/login';

    // Connecté et essaie d'aller sur login → redirige selon rôle
    if (session.isLoggedIn && path == '/login') {
      final role = session.employee?['role'];
      switch (role) {
        case 'admin':
          return '/admin';
        case 'employe':
          return '/employe';
        case 'restaurant':
          return '/restaurant';
        default:
          return '/login';
      }
    }

    // Protection par rôle pour les pages spécifiques
    if (path.startsWith('/admin') && session.employee?['role'] != 'admin') {
      return '/login';
    }
    if (path.startsWith('/employe') && session.employee?['role'] != 'employe') {
      return '/login';
    }
    if (path.startsWith('/restaurant') && session.employee?['role'] != 'restaurant') {
      return '/login';
    }

    return null; // pas de redirection
  }
}