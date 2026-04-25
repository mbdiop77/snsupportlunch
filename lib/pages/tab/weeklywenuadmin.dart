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

  // ================= UTILS =================
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String dayKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  String formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
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
              decoration: const InputDecoration(labelText: "Description du plat si \n c'est nénessaire"),
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

              if (dish.isEmpty) {
                showSnack("Nom obligatoire");
                return;
              }

              Navigator.pop(context);

              try {
                await supabase.from('meals').insert({
                  'dish': dish,
                  'details': detailCtrl.text.trim(),
                });

                await initializeWeekMenus();
                showSnack("Plat ajouté");
              } catch (e) {
                showSnack("Erreur: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= DATE PICKER =================
  Future pickDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: weekMenus[index].date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        weekMenus[index].date = picked;
      });
    }
  }

  // ================= CHECK NEXT WEEK =================
  Future<bool> isNextWeekEmpty() async {
    for (var day in weekMenus) {
      final nextDate = day.date.add(const Duration(days: 7));
      final key = dayKey(nextDate);

      final res = await supabase
          .from('daily_menu')
          .select()
          .eq('menu_date', key)
          .limit(1);

      if (res.isNotEmpty) {
        return false;
      }
    }
    return true;
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
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (_, i) => buildDayCard(i),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: isPublishing
              ? const CircularProgressIndicator()
              : const Icon(Icons.publish),
          label: Text(isPublishing ? "Publication..." : "Publier le menu"),
          onPressed: isPublishing ? null : publishMenu,
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
          InkWell(
            onTap: () => pickDate(index),
            child: Container(
              padding: const EdgeInsets.all(10),
              color: color.withValues(alpha: 0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${getDayName(day.date)} ${formatDate(day.date)}"),
                  const Icon(Icons.edit, size: 16)
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final meal = meals[i];
                final id = meal['id'];

                bool selected = day.selectedMeals.containsKey(id);
                int qty = day.selectedMeals[id] ?? 100;

                return Row(
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
                    Expanded(child: Text(meal['dish'])),
                    if (selected)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                day.selectedMeals[id] =
                                    (qty - 5).clamp(0, 1000);
                              });
                            },
                          ),
                          Text("$qty"),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                day.selectedMeals[id] =
                                    (qty + 5).clamp(0, 1000);
                              });
                            },
                          ),
                        ],
                      )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // ================= PUBLISH + SMART DUP =================
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

      // ===== DUPLICATION INTELLIGENTE =====
      final empty = await isNextWeekEmpty();

      if (empty) {
        for (var day in weekMenus) {
          final newDate = day.date.add(const Duration(days: 7));
          final newKey = dayKey(newDate);

          for (var entry in day.selectedMeals.entries) {
            await supabase.from('daily_menu').insert({
              'menu_date': newKey,
              'meal_id': entry.key,
              'quantity': entry.value,
            });
          }
        }

        showSnack("Menu publié + semaine suivante générée");
      } else {
        showSnack("Menu publié (semaine suivante déjà existante)");
      }
    } catch (e) {
      showSnack("Erreur: $e");
    }

    if (!mounted) return;
    setState(() => isPublishing = false);
  }
}

class DayMenu {
  DateTime date;
  Map<int, int> selectedMeals;

  DayMenu({
    required this.date,
    required this.selectedMeals,
  });
}