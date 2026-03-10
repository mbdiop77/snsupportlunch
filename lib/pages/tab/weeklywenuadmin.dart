import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class WeeklyMenuAdmin extends StatefulWidget {
  const WeeklyMenuAdmin({super.key});

  @override
  State<WeeklyMenuAdmin> createState() => _WeeklyMenuAdminState();
}

class _WeeklyMenuAdminState extends State<WeeklyMenuAdmin>
    with SingleTickerProviderStateMixin {
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

  DateTime now = DateTime.now();

  // Trouver le lundi de la semaine actuelle
  DateTime monday = now.subtract(Duration(days: now.weekday - 1));

  weekMenus = List.generate(
    7,
    (index) => DayMenu(
      date: monday.add(Duration(days: index)),
      selectedMeals: [],
    ),
  );

  loadMealsAndDailyMenu();
}

  /// Charge les repas et les menus déjà publiés
  Future loadMealsAndDailyMenu() async {
    // 1. Charger tous les repas
    final mealResponse = await supabase.from('meals').select();
    final List<Map<String, dynamic>> fetchedMeals =
        List<Map<String, dynamic>>.from(mealResponse);

    // 2. Charger le menu quotidien
    final dailyMenuResponse = await supabase.from('daily_menu').select();
    final List<Map<String, dynamic>> dailyMenus =
        List<Map<String, dynamic>>.from(dailyMenuResponse);

    setState(() {
      meals = fetchedMeals;

      // 3. Associer les meals déjà sélectionnés aux jours correspondants
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
    //  appBar: AppBar(
     //   title: const Text("Planification du menu"),
    //    centerTitle: true,
   //   ),
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
            child:ElevatedButton.icon(
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
                    )
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
          // HEADER
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
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
          // LISTE REPAS
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
          // BOUTONS RAPIDES
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

      /// Publier le menu avec un seul upsert pour chaque jour
    Future publishMenu() async {

  setState(() => isPublishing = true);

  try {

    for (var day in weekMenus) {

      final date =
          "${day.date.year}-${day.date.month.toString().padLeft(2,'0')}-${day.date.day.toString().padLeft(2,'0')}";

      /// repas existants
      final existing = await supabase
          .from('daily_menu')
          .select('meal_id')
          .eq('menu_date', date);

      final existingMeals =
          (existing as List).map((e) => e['meal_id']).toSet();

      final selectedMeals = day.selectedMeals.toSet();

      /// repas à supprimer
      final toDelete = existingMeals.difference(selectedMeals);

      /// repas à ajouter
      final toInsert = selectedMeals.difference(existingMeals);

      if (toDelete.isNotEmpty) {
        await supabase
            .from('daily_menu')
            .delete()
            .eq('menu_date', date)
            .inFilter('meal_id', toDelete.toList());
      }

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