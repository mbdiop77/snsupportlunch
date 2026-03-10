import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportToCSV(List<Map<String, dynamic>> employees) async {
  // 1️⃣ Créer les données CSV
  final headers = ['Matricule', 'Prenom', 'Nom', 'Repas', 'Heure'];
  final rows = employees.map((emp) {
    return [
      emp['matricule'],
      emp['prenom'],
      emp['nom'],
      emp['meal_scans'],
      emp['last_scan_time'] ?? '',
    ];
  }).toList();

  // 2️⃣ Convertir en CSV
  String csv = const ListToCsvConverter().convert([headers, ...rows]);

  // 3️⃣ Sauvegarder dans un fichier temporaire
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/employees_today.csv';
  final file = File(path);
  await file.writeAsString(csv);

  // 4️⃣ Partager le fichier avec ShareParams
  final params = ShareParams(
    text: 'Liste des employés du jour',
    files: [XFile(path)],
  );

  await SharePlus.instance.share(params);
}