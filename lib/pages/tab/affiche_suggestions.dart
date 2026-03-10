import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final supabase = Supabase.instance.client;

  List suggestions = [];
  bool isLoading = true;
  bool todayOnly = false;

  @override
  void initState() {
    super.initState();
    loadSuggestions();
    listenToChanges();
  }

  Future<void> loadSuggestions() async {
    final data = await supabase
        .from('comment')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      suggestions = data;
      isLoading = false;
    });
  }

  void listenToChanges() {
    supabase.channel('comments_channel').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'comment',
      callback: (payload) {
        loadSuggestions();
      },
    ).subscribe();
  }

  bool isToday(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool isNew(String date) {
    final d = DateTime.parse(date);
    return DateTime.now().difference(d).inHours < 24;
  }

  String formatDate(String date) {
    final d = DateTime.parse(date);
    return "Publié le ${d.day}/${d.month}/${d.year} à ${d.hour}:${d.minute}";
  }

  @override
  Widget build(BuildContext context) {
    List filteredSuggestions = todayOnly
        ? suggestions.where((s) => isToday(s['created_at'])).toList()
        : suggestions;

    int columns = MediaQuery.of(context).size.width > 700 ? 1 : 1;

    return Scaffold(
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadSuggestions,
              child: Column(
                children: [
                  // FILTRE
                  Padding(
                    padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                      child: Text(
                        "${filteredSuggestions.length} suggestion(s)",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                      FilterChip(
                        label: const Text("Aujourd'hui"),
                        selected: todayOnly,
                        onSelected: (value) {
                          setState(() {
                            todayOnly = value;
                          });
                        },
                      ),
                    ],
                  ),
                  ),

                  // GRID DYNAMIQUE (Masonry)
                  Expanded(
                    child: MasonryGridView.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = filteredSuggestions[index];
                        return buildSuggestionCard(suggestion);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildSuggestionCard(dynamic suggestion) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Padding(
        padding: const EdgeInsets.all(06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Hauteur dynamique
          children: [
            Row(
              children: [
                const Icon(Icons.feedback, color: Colors.lightBlueAccent, size: 18),
                const SizedBox(width: 2),
                const Expanded(
                  child: Text(
                    "Suggestion",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (isNew(suggestion['created_at']))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Nouveau",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              suggestion['comment_text'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                formatDate(suggestion['created_at']),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}