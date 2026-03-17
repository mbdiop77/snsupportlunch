import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service QR sécurisé
class QrService {
  static const String secretKey = "WAVE_SECRET_KEY";

  static String generateQR(String matricule) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rawData = "$matricule|$timestamp";  // plus de | final inutile
    final signature = sha256.convert(utf8.encode(rawData + secretKey)).toString();
    return "$timestamp|$matricule|$signature";
  }
}