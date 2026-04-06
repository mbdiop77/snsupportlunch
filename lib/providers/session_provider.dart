import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionProvider extends ChangeNotifier {
  Map<String, dynamic>? _employee;

  bool isLoading = true;

  Map<String, dynamic>? get employee => _employee;

  bool get isLoggedIn => _employee != null;

  /// ===========================
  /// 🔹 SAVE SESSION
  /// ===========================
  Future<void> saveSession(Map<String, dynamic> employee) async {
    final prefs = await SharedPreferences.getInstance();

    _employee = employee;

    await prefs.setString('employee', jsonEncode(employee));
    await prefs.setString(
      'login_time',
      DateTime.now().toIso8601String(),
    );

    isLoading = false;
    notifyListeners();
  }

  /// ===========================
  /// 🔹 LOAD SESSION
  /// ===========================
  Future<void> loadSession() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final employeeString = prefs.getString('employee');
    final loginTimeString = prefs.getString('login_time');

    if (employeeString != null && loginTimeString != null) {
      try {
        final loginTime = DateTime.parse(loginTimeString);

        final isValid =
            DateTime.now().difference(loginTime).inHours < 24;

        if (isValid) {
          _employee =
              Map<String, dynamic>.from(jsonDecode(employeeString));
        } else {
          await _clearLocalSession(prefs);
        }
      } catch (e) {
        debugPrint("Session error: $e");
        _employee = null;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  /// ===========================
  /// 🔹 LOGOUT (USER ACTION)
  /// ===========================
  Future<void> logout() async {
    await forceLogout();
  }

  /// ===========================
  /// 🔥 FORCE LOGOUT (ADMIN / DEVICE)
  /// ===========================
  Future<void> forceLogout() async {
       debugPrint("FORCE LOGOUT TRIGGERED");
    final prefs = await SharedPreferences.getInstance();

    // 🔐 1. Déconnexion Supabase
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("Erreur signOut: $e");
    }

    // 🧹 2. Nettoyage local
    await _clearLocalSession(prefs);

    // 🧠 3. Reset mémoire
    _employee = null;

    // 🔄 4. Notifie GoRouter
    notifyListeners();
  }

  /// ===========================
  /// 🧹 CLEAR LOCAL SESSION
  /// ===========================
  Future<void> _clearLocalSession(SharedPreferences prefs) async {
    await prefs.remove('employee');
    await prefs.remove('login_time');
  }
}