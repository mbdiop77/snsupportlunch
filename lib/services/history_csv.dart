//import 'dart:io';
//import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
//import 'package:path_provider/path_provider.dart';
//import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
Future<void> exportToPDF(List<Map<String, dynamic>> employees) async {

  final pdf = pw.Document();

  final headers = ['Matricule', 'Prenom-nom','Repas', 'Heure'];
final rows = employees.map((emp) {
  final prenom = emp['prenom'] ?? '';
  final nom = emp['nom'] ?? '';

  // Fusion prénom + nom (avec espace seulement si nom existe)
  final fullName = nom.isNotEmpty ? "$prenom $nom" : prenom;

  // Extraire uniquement l'heure
  String time = '';
  if (emp['scanned_at'] != null) {
    final dateTime = DateTime.parse(emp['scanned_at']);
    time =
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  return [
    emp['matricule'] ?? '',
    fullName,
    emp['dish'] ?? '-----',
    time,
  ];
}).toList();

  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
        );
      },
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'repas.pdf',
  );
}