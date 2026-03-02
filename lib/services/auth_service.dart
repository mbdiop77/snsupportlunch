import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

Future<Map<String, dynamic>?> login(String matricule, String password) async {
  if (matricule.isEmpty) {
    throw Exception("Veuillez entrer le matricule");
  }

  final int? parsedMatricule = int.tryParse(matricule);

  if (parsedMatricule == null) {
    throw Exception("Le matricule doit être un nombre");
  }

  final employee = await supabase
      .from('employees')
      .select()
      .eq('matricule', parsedMatricule)
      .maybeSingle();

  if (employee == null) {
    throw Exception("Matricule introuvable");
  }

  if (employee['password_hash'] == null) {
    return {
      "needsPassword": true,
      "employee": employee
    };
  }

  final hashedInput = hashPassword(password);

  if (hashedInput != employee['password_hash']){
    throw Exception("Mot de passe incorrect");
  }

    return {
      "needsPassword": false,
      "employee": employee
    };
  }
}