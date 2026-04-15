import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// 🔹 1. Déclenche Google SSO
  Future<void> signInWithGoogle({required String redirectTo}) async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }
/// 🔹 Login Google + sync employees + validation
Future<Map<String, dynamic>?> loginWithGoogle() async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception("Utilisateur non connecté");
  }

  final email = user.email;

  if (email == null) {
    throw Exception("Email utilisateur introuvable");
  }

  /// 🔐 1. Vérification domaine entreprise
  if (!email.endsWith('@wave.com')) {
    throw Exception("Accès refusé : domaine non autorisé");
  }

  /// 🔍 2. Cherche l'employé dans la table
  var employee = await supabase
      .from('employees')
      .select()
      .eq('email', email)
      .maybeSingle();

  /// 👤 3. Si pas trouvé → création automatique (provisioning)
  if (employee == null) {

    /// 🔑 génération matricule depuis user.id (6 premiers caractères)
    final matricule = user.id.substring(0, 6);

    await supabase.from('employees').insert({
      'email': email,
      'prenom': user.userMetadata?['full_name'] ?? '',
      'status': true, // ou false selon ton flow métier
      'role': 'employe', // défaut
      'matricule': matricule, // 👈 AJOUT ICI
      'created_at': DateTime.now().toIso8601String(),
    });

    /// 🔄 re-fetch pour récupérer l'enregistrement complet
    employee = await supabase
        .from('employees')
        .select()
        .eq('email', email)
        .maybeSingle();
  }

  /// 🚫 4. Vérification statut employé
  if (employee == null) {
    throw Exception("Utilisateur introuvable après création");
  }

  if (employee['status'] == false) {
    throw Exception("Accès refusé, merci de contacter l'admin de la plateforme");
  }

  /// ✅ 5. Retour final
  return {
    "employee": employee,
  };
}

  /// 🔹 3. Logout SSO
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}