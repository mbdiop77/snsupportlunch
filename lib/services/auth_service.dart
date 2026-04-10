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

  /// 🔹 2. Récupère l'employé après connexion
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    final user = supabase.auth.currentUser;

    final email = user?.email;
    //debugPrint("USER EMAIL: ${user?.email}");
    if (email == null) {
      throw Exception("Email utilisateur introuvable");
    }

    final employee = await supabase
        .from('employees')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (employee == null) {
      throw Exception("Utilisateur non autorisé");
    }

    if (employee['status'] == false) {
      throw Exception("Accès refusé,merci de contacter l'admin de la plateforme");
    }

    return {
      "employee": employee,
    };
  }

  /// 🔹 3. Logout SSO
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}