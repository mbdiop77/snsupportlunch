import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuDuJourSheet extends StatefulWidget {
  const MenuDuJourSheet({super.key});

  @override
  State<MenuDuJourSheet> createState() => _MenuDuJourSheetState();
}

class _MenuDuJourSheetState extends State<MenuDuJourSheet> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> menus = [];
  bool isLoading = true;
  int? expandedIndex; // index du plat dont les détails sont affichés

  @override
  void initState() {
    super.initState();
    loadMenu();
  }

  Future<void> loadMenu() async {
    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final data = await supabase
          .from('daily_menu')
          .select('meal_id, meals!fk_meals(dish, details)')
          .eq('menu_date', todayDate);

      setState(() {
        menus = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur Supabase: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // TITRE FIXE
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Menu du jour",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // CONTENU DU MENU
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : menus.isEmpty
                        ? const Center(child: Text("Aucun menu aujourd'hui"))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: menus.length,
                            itemBuilder: (context, index) {
                              final meal = menus[index]['meals'];
                              final mealname = meal?['dish'] ?? 'Plat inconnu';
                              final details = meal?['details'] ?? '   Pas de détails pour ce plat';

                              final isExpanded = expandedIndex == index;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    title: Text(mealname),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isExpanded) {
                                            expandedIndex = null;
                                          } else {
                                            expandedIndex = index;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 06, vertical: 4),
                                      child: Text(
                                        details,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  const Divider(height: 1),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}