//import 'dart:io';
//import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
//import 'package:path_provider/path_provider.dart';
//import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
Future<void> exportToPDF(List<Map<String, dynamic>> employees) async {

  final pdf = pw.Document();

  final headers = ['Matricule', 'Prenom', 'Nom', 'Repas', 'Heure'];

  final rows = employees.map((emp) {
    return [
      emp['matricule'] ?? '',
      emp['prenom'] ?? '',
      emp['nom'] ?? '',
      emp['dish'] ?? '',
      emp['scanned_at'] ?? '',
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