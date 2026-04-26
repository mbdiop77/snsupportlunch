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
    Colors.red,
  ];

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    initializeWeekMenus();
  }

  // ================= UTILS =================
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String dayKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  String formatDate(DateTime d) {
    return "${d.day}/${d.month}/${d.year}";
  }

  String getDayName(DateTime date) {
    const days = [
      "Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"
    ];
    return days[date.weekday - 1];
  }

  // ================= INIT DATA =================
  Future initializeWeekMenus() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    weekMenus = List.generate(
      7,
      (i) => DayMenu(
        date: monday.add(Duration(days: i)),
        selectedMeals: {},
      ),
    );

    final mealsRes = await supabase.from('meals').select().order('dish');
    final menuRes = await supabase.from('daily_menu').select();

    if (!mounted) return;

    meals = List<Map<String, dynamic>>.from(mealsRes);
    final dailyMenus = List<Map<String, dynamic>>.from(menuRes);

    setState(() {
      for (var day in weekMenus) {
        final key = dayKey(day.date);

        final map = <int, int>{};

        for (var dm in dailyMenus.where((e) => e['menu_date'] == key)) {
          map[dm['meal_id']] = dm['quantity'] ?? 100;
        }

        day.selectedMeals = map;
      }
    });
  }

  // ================= ADD PLAT =================
  void showAddDishDialog() {
    final dishCtrl = TextEditingController();
    final detailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nouveau repas"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dishCtrl,
              decoration: const InputDecoration(labelText: "Nom du repas"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Description (optionnel)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final dish = dishCtrl.text.trim();
              final detail = detailCtrl.text.trim();

              if (dish.isEmpty) return;

              Navigator.pop(context);

              try {
                await supabase.from('meals').insert({
                  'dish': dish,
                  'details': detail,
                });

                await initializeWeekMenus();
                showSnack("Un nouveau repas enregistré");
              } catch (e) {
                showSnack("Erreur: $e");
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ✅ bouton ajouté en haut (remplace AppBar)
          SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(1),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: showAddDishDialog,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(1),
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int cols = 4;
                if (constraints.maxWidth < 900) cols = 2;
                if (constraints.maxWidth < 600) cols = 1;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: 7,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (_, i) => buildDayCard(i),
                );
              },
            ),
          ),
        ],
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // 🔥 HEADER FULL WIDTH
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Column(
              children: [
                Text(
                  getDayName(day.date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(formatDate(day.date)),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final meal = meals[i];
                final id = meal['id'];
                final name = meal['dish'];

                final selected = day.selectedMeals.containsKey(id);
                final qty = day.selectedMeals[id] ?? 100;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              day.selectedMeals[id] = 100;
                            } else {
                              day.selectedMeals.remove(id);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // 🔥 +/- RESTAURÉ
                      if (selected)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                setState(() {
                                  day.selectedMeals[id] =
                                      (qty - 5).clamp(0, 1000);
                                });
                              },
                            ),
                            Text("$qty"),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () {
                                setState(() {
                                  day.selectedMeals[id] =
                                      (qty + 5).clamp(0, 1000);
                                });
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
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

        final selectedSet = day.selectedMeals.keys.toSet();

        // ❌ DELETE non cochés
        final toDelete = existingSet.difference(selectedSet);

        if (toDelete.isNotEmpty) {
          await supabase
              .from('daily_menu')
              .delete()
              .eq('menu_date', key)
              .filter('meal_id', 'in', toDelete.toList());
        }

        // ➕ INSERT / UPDATE
        for (var entry in day.selectedMeals.entries) {
          final mealId = entry.key;
          final qty = entry.value;

          if (existingSet.contains(mealId)) {
            await supabase
                .from('daily_menu')
                .update({'quantity': qty})
                .eq('menu_date', key)
                .eq('meal_id', mealId);
          } else {
            await supabase.from('daily_menu').insert({
              'menu_date': key,
              'meal_id': mealId,
              'quantity': qty,
            });
          }
        }
      }

      showSnack("Menu mis à jour");
    } catch (e) {
      showSnack("Erreur: $e");
    }

    setState(() => isPublishing = false);
  }
}

// ================= MODEL =================
class DayMenu {
  DateTime date;
  Map<int, int> selectedMeals;

  DayMenu({
    required this.date,
    required this.selectedMeals,
  });
}