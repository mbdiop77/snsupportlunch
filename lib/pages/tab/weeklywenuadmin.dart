import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class WeeklyMenuAdmin extends StatefulWidget {
  const WeeklyMenuAdmin({super.key});

  @override
  State<WeeklyMenuAdmin> createState() => _WeeklyMenuAdminState();
}

class _WeeklyMenuAdminState extends State<WeeklyMenuAdmin> {
  bool isPublishing = false;

  List<Map<String, dynamic>> meals = [];
  late List<DayMenu> weekMenus;

  final List<Color> dayColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.red
  ];

  @override
  void initState() {
    super.initState();
    initializeWeekMenus();
  }

  // ================= UTILS =================
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String dayKey(DateTime d) {
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }

  String formatDate(DateTime d) {
    return "${d.day}/${d.month}";
  }

  String getDayName(DateTime date) {
    const days = [
      "Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"
    ];
    return days[date.weekday - 1];
  }

  // ================= INIT =================
  Future initializeWeekMenus() async {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    weekMenus = List.generate(
      7,
      (i) => DayMenu(
        date: monday.add(Duration(days: i)),
        selectedMeals: [],
      ),
    );

    final mealsRes = await supabase.from('meals').select().order('dish');
    final menuRes = await supabase.from('daily_menu').select();

    if (!mounted) return;

    meals = List<Map<String, dynamic>>.from(mealsRes);
    final dailyMenus = List<Map<String, dynamic>>.from(menuRes);

    // ✅ Vérifier si semaine actuelle vide
    bool hasMenu = dailyMenus.any((dm) {
      DateTime d = DateTime.parse(dm['menu_date']);
      return d.isAfter(monday.subtract(const Duration(days: 1))) &&
          d.isBefore(monday.add(const Duration(days: 7)));
    });

    // ✅ Copier semaine passée si vide
    if (!hasMenu) {
      await copyLastWeekMenu(monday, dailyMenus);
    }

    // ✅ Charger les données
    setState(() {
      for (var day in weekMenus) {
        final key = dayKey(day.date);

        day.selectedMeals = dailyMenus
            .where((dm) => dm['menu_date'] == key)
            .map<int>((dm) => dm['meal_id'] as int)
            .toList();
      }
    });
  }

  // ================= COPY LAST WEEK =================
  Future copyLastWeekMenu(
      DateTime thisMonday, List<Map<String, dynamic>> dailyMenus) async {
    DateTime lastMonday = thisMonday.subtract(const Duration(days: 7));

    final lastWeekMenus = dailyMenus.where((dm) {
      DateTime d = DateTime.parse(dm['menu_date']);
      return d.isAfter(lastMonday.subtract(const Duration(days: 1))) &&
          d.isBefore(lastMonday.add(const Duration(days: 7)));
    }).toList();

    for (var dm in lastWeekMenus) {
      DateTime old = DateTime.parse(dm['menu_date']);
      DateTime newDate =
          thisMonday.add(Duration(days: old.weekday - 1));

      final newKey = dayKey(newDate);

      final exists = dailyMenus.any((e) =>
          e['menu_date'] == newKey && e['meal_id'] == dm['meal_id']);

      if (!exists) {
        await supabase.from('daily_menu').insert({
          'menu_date': newKey,
          'meal_id': dm['meal_id'],
        });

        dailyMenus.add({
          'menu_date': newKey,
          'meal_id': dm['meal_id'],
        });
      }
    }
  }

  // ================= ADD DISH =================
void showAddDishDialog() {
  final dishCtrl = TextEditingController();
  final detailCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Ajouter un nouveau plat"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: dishCtrl,
            decoration: const InputDecoration(
              labelText: "Nom du plat",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: detailCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Description (optionnel)",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          child: const Text("Ajouter"),
          onPressed: () async {
            final dish = dishCtrl.text.trim();
            final detail = detailCtrl.text.trim();

            if (dish.isEmpty) {
              showSnack("Le nom du plat est obligatoire");
              return;
            }

            Navigator.pop(context); // ✅ safe

            try {
              await supabase.from('meals').insert({
                'dish': dish,
                'details': detail,
              });

              if (!mounted) return;

              await initializeWeekMenus();
              showSnack("Plat ajouté");
            } catch (e) {
              if (!mounted) return;
              showSnack("Erreur: $e");
            }
          },
        ),
      ],
    ),
  );
}

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
       // title: const Text("Menu hebdomadaire"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddDishDialog,
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int cols = 4; // 💻 2 lignes
          if (constraints.maxWidth < 900) cols = 2;
          if (constraints.maxWidth < 600) cols = 1;

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 7,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2, // 🔥 compact
            ),
            itemBuilder: (_, i) => buildDayCard(i),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: isPublishing ? null : publishMenu,
          child: Text(isPublishing ? "Publication..." : "Publier le menu"),
        ),
      ),
    );
  }

  // ================= CARD =================
  Widget buildDayCard(int index) {
    final day = weekMenus[index];
    final color = dayColors[index];

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            color: color.withValues(alpha: 0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${getDayName(day.date)} ${formatDate(day.date)}"),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: day.date,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() => day.date = picked);
                    }
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final meal = meals[i];
                final id = meal['id'];

                return CheckboxListTile(
                  dense: true,
                  value: day.selectedMeals.contains(id),
                  title: Text(meal['dish']),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        day.selectedMeals.add(id);
                      } else {
                        day.selectedMeals.remove(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= PUBLISH =================
  Future publishMenu() async {
    setState(() => isPublishing = true);

    try {
      for (var day in weekMenus) {
        final key = dayKey(day.date);

        final existing = await supabase
            .from('daily_menu')
            .select('meal_id')
            .eq('menu_date', key);

        final existingSet =
            (existing as List).map((e) => e['meal_id']).toSet();

        final selectedSet = day.selectedMeals.toSet();

        // 🔥 DELETE NON COCHÉ
        final toDelete = existingSet.difference(selectedSet);

        if (toDelete.isNotEmpty) {
          await supabase
              .from('daily_menu')
              .delete()
              .eq('menu_date', key)
              .inFilter('meal_id', toDelete.toList());
        }

        // 🔥 INSERT NOUVEAUX
        final toInsert = selectedSet.difference(existingSet);

        if (toInsert.isNotEmpty) {
          await supabase.from('daily_menu').insert(
            toInsert
                .map((id) => {
                      'meal_id': id,
                      'menu_date': key,
                    })
                .toList(),
          );
        }
      }

      showSnack("Menu mis à jour");
    } catch (e) {
      showSnack("Erreur: $e");
    }

    setState(() => isPublishing = false);
  }
}

class DayMenu {
  DateTime date;
  List<int> selectedMeals;

  DayMenu({required this.date, required this.selectedMeals});
}