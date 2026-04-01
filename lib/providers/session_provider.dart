import 'dart:convert'; // pour jsonEncode / jsonDecode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProvider extends ChangeNotifier {
  Map<String, dynamic>? _employee;

  /// ⚡ Indique si la session est en cours de chargement
  bool isLoading = true;

  /// Getter pour accéder à l'employee
  Map<String, dynamic>? get employee => _employee;

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => _employee != null;

  /// Sauvegarde la session complète et l'heure de connexion
  Future<void> saveSession(Map<String, dynamic> employee) async {
    _employee = employee;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employee', jsonEncode(employee)); // sauvegarde JSON complet

    // Stocke l'heure de connexion
    await prefs.setString(
      'login_time',
      DateTime.now().toIso8601String(),
    );

    notifyListeners();
  }

  /// Charge la session depuis SharedPreferences
  /// Supprime la session si elle a expiré (24h)
  Future<void> loadSession() async {
    isLoading = true; // ⚡ début du chargement
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final employeeString = prefs.getString('employee');
    final loginTimeString = prefs.getString('login_time');

    if (employeeString != null && loginTimeString != null) {
      try {
        DateTime loginTime = DateTime.parse(loginTimeString);
        DateTime now = DateTime.now();

        // Vérifie si plus de 24h se sont écoulées
        if (now.difference(loginTime).inHours >= 24) {
          // Session expirée : on supprime tout
          _employee = null;
          await prefs.remove('employee');
          await prefs.remove('login_time');
          isLoading = false;
          notifyListeners();
          return;
        }

        // Session encore valide
        _employee = Map<String, dynamic>.from(jsonDecode(employeeString));
      } catch (e) {
        // Si JSON invalide ou erreur, supprime la session
        _employee = null;
        await prefs.remove('employee');
        await prefs.remove('login_time');
      }
    }

    isLoading = false; // ⚡ fin du chargement
    notifyListeners();
  }

  /// Met à jour l'employee en mémoire (utile après login)
  void setEmployee(Map<String, dynamic> employee) {
    _employee = employee;
    notifyListeners();
  }

  /// Déconnecte l'utilisateur et supprime la session
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('employee');
    await prefs.remove('login_time');
    _employee = null;
    notifyListeners();
  }
}