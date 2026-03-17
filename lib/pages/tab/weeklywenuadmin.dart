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

  /// Initialise la semaine en chargeant les repas existants et en copiant la semaine passée si nécessaire
  Future initializeWeekMenus() async {
    // 1️⃣ Calcul de la semaine actuelle
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    weekMenus = List.generate(
      7,
      (index) => DayMenu(
        date: monday.add(Duration(days: index)),
        selectedMeals: [],
      ),
    );

    // 2️⃣ Charger tous les repas
    final mealResponse = await supabase.from('meals').select();
    meals = List<Map<String, dynamic>>.from(mealResponse);

    // 3️⃣ Vérifier si un menu existe déjà pour la semaine actuelle
    final dailyMenuResponse = await supabase.from('daily_menu').select();
    final List<Map<String, dynamic>> dailyMenus =
        List<Map<String, dynamic>>.from(dailyMenuResponse);

    bool hasMenu = dailyMenus.any((dm) {
      DateTime menuDate = DateTime.parse(dm['menu_date']);
      return menuDate.isAfter(monday.subtract(const Duration(days: 1))) &&
          menuDate.isBefore(monday.add(const Duration(days: 7)));
    });

    // 4️⃣ Copier la semaine passée si nécessaire
    if (!hasMenu) {
      await copyLastWeekMenu(monday, dailyMenus);
    }

    // 5️⃣ Associer les repas existants aux jours
    setState(() {
      for (var day in weekMenus) {
        String dayString =
            "${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}";
        day.selectedMeals = dailyMenus
            .where((dm) => dm['menu_date'].toString() == dayString)
            .map<int>((dm) => dm['meal_id'] as int)
            .toList();
      }
    });
  }

  /// Copie le menu de la semaine passée dans la nouvelle semaine
  Future copyLastWeekMenu(DateTime thisMonday, List<Map<String, dynamic>> dailyMenus) async {
    DateTime lastMonday = thisMonday.subtract(const Duration(days: 7));

    final lastWeekMenus = dailyMenus.where((dm) {
      DateTime menuDate = DateTime.parse(dm['menu_date']);
      return menuDate.isAfter(lastMonday.subtract(const Duration(days: 1))) &&
          menuDate.isBefore(lastMonday.add(const Duration(days: 7)));
    }).toList();

    for (var dm in lastWeekMenus) {
      DateTime oldDate = DateTime.parse(dm['menu_date']);
      int weekday = oldDate.weekday; // lundi = 1
      DateTime newDate = thisMonday.add(Duration(days: weekday - 1));

      // Vérifier si le menu existe déjà
      final exists = dailyMenus.any((d) => d['menu_date'] == newDate.toIso8601String() && d['meal_id'] == dm['meal_id']);
      if (!exists) {
        await supabase.from('daily_menu').insert({
          'menu_date': newDate.toIso8601String(),
          'meal_id': dm['meal_id'],
        });
        // Ajouter à dailyMenus local pour que l'UI se mette à jour
        dailyMenus.add({
          'menu_date': newDate.toIso8601String(),
          'meal_id': dm['meal_id'],
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 3;
                if (constraints.maxWidth < 900) crossAxisCount = 2;
                if (constraints.maxWidth < 600) crossAxisCount = 1;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 7,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + index * 100),
                      curve: Curves.easeOut,
                      child: buildDayCard(index),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: isPublishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish),
              label: Text(isPublishing ? "Publication..." : "Publier le menu"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isPublishing ? null : publishMenu,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDayCard(int index) {
    final day = weekMenus[index];
    final color = dayColors[index];

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color : color.withValues(alpha: 150),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  getDayName(day.date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: day.date,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() {
                        day.date = picked;
                      });
                    }
                  },
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              "${day.date.day}/${day.date.month}/${day.date.year}",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(),
          Expanded(
            child: meals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: meals.length,
                    itemBuilder: (context, i) {
                      final meal = meals[i];
                      final mealId = meal['id'] as int;
                      final mealName = meal['dish'] as String? ?? 'Repas';
                      bool isSelected = day.selectedMeals.contains(mealId);

                      return CheckboxListTile(
                        dense: true,
                        title: Text(mealName),
                        value: isSelected,
                        activeColor: color,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              day.selectedMeals.add(mealId);
                            } else {
                              day.selectedMeals.remove(mealId);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  child: const Text("Tout"),
                  onPressed: () {
                    setState(() {
                      day.selectedMeals =
                          meals.map<int>((m) => m['id'] as int).toList();
                    });
                  },
                ),
                TextButton(
                  child: const Text("Aucun"),
                  onPressed: () {
                    setState(() {
                      day.selectedMeals.clear();
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// Publier le menu avec upsert intelligent
Future publishMenu() async {
  setState(() => isPublishing = true);

  try {
    for (var day in weekMenus) {
      final date = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
      ).toIso8601String();

      // repas existants
      final existing = await supabase
          .from('daily_menu')
          .select('meal_id')
          .eq('menu_date', date);

      final existingMeals =
          (existing as List).map((e) => e['meal_id']).toSet();

      final selectedMeals = day.selectedMeals.toSet();

      // repas à supprimer
      final toDelete = existingMeals.difference(selectedMeals);

      if (toDelete.isNotEmpty) {
        await supabase
            .from('daily_menu')
            .delete()
            .eq('menu_date', date)
            .inFilter('meal_id', toDelete.toList());
      }

      // repas à ajouter
      final toInsert = selectedMeals.difference(existingMeals);

      if (toInsert.isNotEmpty) {
        await supabase.from('daily_menu').insert(
          toInsert
              .map((mealId) => {
                    'meal_id': mealId,
                    'menu_date': date,
                  })
              .toList(),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Menu mis à jour")),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

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
  List<int> selectedMeals;

  DayMenu({required this.date, required this.selectedMeals});
}