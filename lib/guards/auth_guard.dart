import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/session_provider.dart';

class AuthGuard {
  final SessionProvider session;

  AuthGuard(this.session);

  String? redirect(BuildContext context, GoRouterState state) {
  if (session.isLoading) return null; // ⚡ attend que la session soit chargée

  final path = state.uri.path;

  // Non connecté → login
  if (!session.isLoggedIn && path != '/login') return '/login';

  // Connecté → redirection selon rôle
  if (session.isLoggedIn && path == '/login') {
    final role = session.employee?['role'];
    switch (role) {
      case 'admin':
      case 'subadmin': 
        return '/admin';
      case 'employe':
        return '/employe';
      case 'restaurant':
        return '/restaurant';
      default:
        return '/login';
    }
  }

  // Protection par rôle
  if (path.startsWith('/admin') && session.employee?['role'] != 'admin') return '/login';
  if (path.startsWith('/employe') && session.employee?['role'] != 'employe') return '/login';
  if (path.startsWith('/restaurant') && session.employee?['role'] != 'restaurant') return '/login';

  return null;
}
 }