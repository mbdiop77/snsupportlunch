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

  // ================= SAFE SNACK =================
  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ================= INIT =================
  Future initializeWeekMenus() async {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    weekMenus = List.generate(
      7,
      (index) => DayMenu(
        date: monday.add(Duration(days: index)),
        selectedMeals: {},
      ),
    );

    final mealResponse = await supabase.from('meals').select();
    final dailyMenuResponse = await supabase.from('daily_menu').select();

    if (!mounted) return;

    meals = List<Map<String, dynamic>>.from(mealResponse);
    final dailyMenus = List<Map<String, dynamic>>.from(dailyMenuResponse);

    setState(() {
      for (var day in weekMenus) {
        String dayString =
            "${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}";

        Map<int, int> map = {};

        for (var dm in dailyMenus.where(
            (dm) => dm['menu_date'].toString().startsWith(dayString))) {
          map[dm['meal_id']] = dm['quantity'] ?? 100;
        }

        day.selectedMeals = map;
      }
    });
  }

  // ================= ADD DISH =================
  void showAddDishDialog() {
    final dishController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter un plat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dishController,
              decoration: const InputDecoration(labelText: "Nom du plat"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Détails"),
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
              final dish = dishController.text.trim();
              if (dish.isEmpty) return;

              Navigator.pop(context); // fermer AVANT async

              await supabase.from('meals').insert({
                'dish': dish,
                'details': detailsController.text.trim(),
              });

              if (!mounted) return;

              await initializeWeekMenus();
              showSnack("Plat ajouté");
            },
          )
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Hebdomadaire"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddDishDialog,
          )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemBuilder: (_, i) => buildDayCard(i),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: isPublishing ? null : publishMenu,
          child: Text(isPublishing ? "Publication..." : "Publier"),
        ),
      ),
    );
  }

  Widget buildDayCard(int index) {
    final day = weekMenus[index];
    final color = dayColors[index];

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: color.withValues(alpha: 0.2),
            child: Text(getDayName(day.date)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final meal = meals[i];
                final id = meal['id'];
                final name = meal['dish'];

                bool isSelected = day.selectedMeals.containsKey(id);
                int qty = day.selectedMeals[id] ?? 100;

                return Column(
                  children: [
                    CheckboxListTile(
                      title: Text(name),
                      value: isSelected,
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
                    if (isSelected)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                if (qty > 0) {
                                  day.selectedMeals[id] = qty - 10;
                                }
                              });
                            },
                          ),
                          Text("$qty"),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                day.selectedMeals[id] = qty + 10;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= PUBLISH (SAFE) =================
  Future publishMenu() async {
    setState(() => isPublishing = true);

    try {
      for (var day in weekMenus) {
        DateTime start =
            DateTime(day.date.year, day.date.month, day.date.day);
        DateTime end = start.add(const Duration(days: 1));

        final existing = await supabase
            .from('daily_menu')
            .select()
            .gte('menu_date', start.toIso8601String())
            .lt('menu_date', end.toIso8601String());

        final existingMeals =
            (existing as List).map((e) => e['meal_id']).toSet();

        final selectedMeals = day.selectedMeals.keys.toSet();

        final toDelete = existingMeals.difference(selectedMeals);

        if (toDelete.isNotEmpty) {
          await supabase
              .from('daily_menu')
              .delete()
              .gte('menu_date', start.toIso8601String())
              .lt('menu_date', end.toIso8601String())
              .inFilter('meal_id', toDelete.toList());
        }

        final toInsert = selectedMeals.difference(existingMeals);

        if (toInsert.isNotEmpty) {
          await supabase.from('daily_menu').insert(
            toInsert.map((id) {
              return {
                'meal_id': id,
                'menu_date': start.toIso8601String(),
                'quantity': day.selectedMeals[id] ?? 100,
              };
            }).toList(),
          );
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

class DayMenu {
  DateTime date;
  Map<int, int> selectedMeals;

  DayMenu({required this.date, required this.selectedMeals});
}