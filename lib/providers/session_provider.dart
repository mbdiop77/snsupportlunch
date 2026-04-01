import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProvider extends ChangeNotifier {
  Map<String, dynamic>? _employee;

  bool isLoading = true;

  Map<String, dynamic>? get employee => _employee;

  bool get isLoggedIn => _employee != null;

  /// 🔹 Sauvegarde session
  Future<void> saveSession(Map<String, dynamic> employee) async {
    _employee = employee;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employee', jsonEncode(employee));
    await prefs.setString(
      'login_time',
      DateTime.now().toIso8601String(),
    );

    isLoading = false; // 🔥 IMPORTANT
    notifyListeners();
  }

  /// 🔹 Chargement session au démarrage
  Future<void> loadSession() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final employeeString = prefs.getString('employee');
    final loginTimeString = prefs.getString('login_time');

    if (employeeString != null && loginTimeString != null) {
      try {
        final loginTime = DateTime.parse(loginTimeString);

        if (DateTime.now().difference(loginTime).inHours < 24) {
          _employee = Map<String, dynamic>.from(jsonDecode(employeeString));
        } else {
          await prefs.remove('employee');
          await prefs.remove('login_time');
        }
      } catch (_) {
        _employee = null;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  /// 🔹 Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _employee = null;
    notifyListeners();
  }
}