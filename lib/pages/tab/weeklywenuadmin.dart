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

  @override
  void initState() {
    super.initState();
    initializeWeekMenus();
  }

  // ================= SNACK SAFE =================
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ================= DATE KEY =================
  String dayKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  // ================= INIT =================
  Future initializeWeekMenus() async {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    weekMenus = List.generate(
      7,
      (i) => DayMenu(
        date: monday.add(Duration(days: i)),
        selectedMeals: {},
      ),
    );

    final mealsRes = await supabase.from('meals').select();
    final menuRes = await supabase.from('daily_menu').select();

    if (!mounted) return;

    meals = List<Map<String, dynamic>>.from(mealsRes);
    final dailyMenus = List<Map<String, dynamic>>.from(menuRes);

    setState(() {
      for (var day in weekMenus) {
        final key = dayKey(day.date);

        final map = <int, int>{};

        for (var dm in dailyMenus.where((e) => e['menu_name'] == key)) {
          map[dm['meal_id']] = dm['quantity'] ?? 100;
        }

        day.selectedMeals = map;
      }
    });
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
              decoration: const InputDecoration(labelText: "Nom du plat"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Desctription du plat si c'est nécessaire"),
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
              if (dish.isEmpty) return;

              Navigator.pop(context);

              await supabase.from('meals').insert({
                'dish': dish,
                'details': detailCtrl.text.trim(),
              });

              if (!mounted) return;

              await initializeWeekMenus();
              showSnack("Plat ajouté");
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
        title: const Text("Menu hebdomadaire"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddDishDialog,
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int cols = 3;
          if (constraints.maxWidth < 900) cols = 2;
          if (constraints.maxWidth < 600) cols = 1;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 7,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (_, i) => buildDayCard(i),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: isPublishing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish),
          label: Text(isPublishing ? "Publication..." : "Publier le menu"),
          onPressed: isPublishing ? null : publishMenu,
        ),
      ),
    );
  }

  // ================= CARD JOUR =================
  Widget buildDayCard(int index) {
    final day = weekMenus[index];
    final color = dayColors[index];

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // HEADER COLORÉ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              getDayName(day.date),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final meal = meals[i];
                final id = meal['id'];
                final name = meal['dish'];

                bool selected = day.selectedMeals.containsKey(id);
                int qty = day.selectedMeals[id] ?? 100;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // CHECKBOX
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

                      // PLAT
                      Expanded(
                        child: Text(name),
                      ),

                      // QUANTITÉ + BOUTONS (ALIGNÉS PROPREMENT)
                      if (selected)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  day.selectedMeals[id] =
                                      (qty - 5).clamp(0, 1000);
                                });
                              },
                            ),
                            Text(
                              "$qty",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
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
            .select()
            .eq('menu_date', key);

        final existingMap = {
          for (var e in existing) e['meal_id']: e['quantity']
        };

        final selectedMap = day.selectedMeals;

        // DELETE
        final toDelete = existingMap.keys
            .where((id) => !selectedMap.containsKey(id))
            .toList();

        if (toDelete.isNotEmpty) {
          await supabase
              .from('daily_menu')
              .delete()
              .eq('menu_date', key)
              .inFilter('meal_id', toDelete);
        }

        // INSERT / UPDATE
        for (var entry in selectedMap.entries) {
          final id = entry.key;
          final qty = entry.value;

          if (existingMap.containsKey(id)) {
            if (existingMap[id] != qty) {
              await supabase
                  .from('daily_menu')
                  .update({'quantity': qty})
                  .eq('menu_date', key)
                  .eq('meal_id', id);
            }
          } else {
            await supabase.from('daily_menu').insert({
              'menu_date': key,
              'meal_id': id,
              'quantity': qty,
            });
          }
        }
      }

      if (!mounted) return;
      showSnack("Menu publié");
    } catch (e) {
      if (!mounted) return;
      showSnack("Erreur: $e");
    }

    if (!mounted) return;
    setState(() => isPublishing = false);
  }

  String getDayName(DateTime date) {
    const days = [
      "Lundi",
      "Mardi",
      "Mercredi",
      "Jeudi",
      "Vendredi",
      "Samedi",
      "Dimanche"
    ];
    return days[date.weekday - 1];
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