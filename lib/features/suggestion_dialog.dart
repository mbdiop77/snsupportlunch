import 'package:flutter/material.dart';

class SuggestionDialog {
  static void show(BuildContext context, Function(String) onSubmit) {
    final TextEditingController controller = TextEditingController();
    const int maxChars = 250;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(08),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// Icône
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFFFFF3CD),
                      child: Icon(
                        Icons.feedback,
                        color: Colors.lightBlueAccent,
                        size: 15,
                      ),
                    ),

                   // const SizedBox(height: 6),

                    /// Titre
                    const Text(
                      "Une idée pour améliorer le service ?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                 //   const SizedBox(height: 6),

                    const Text(
                      "Votre suggestion nous aide à améliorer l'expérience client.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12,color: Colors.grey),
                    ),

                 //   const SizedBox(height: 6),

                    /// Champ texte
                    TextField(
                      controller: controller,
                      maxLength: maxChars,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Écrivez votre suggestion ici...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 05),

                    /// Boutons
                   OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 10,
                  overflowSpacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Annuler"),
                    ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text("Envoyer"),
                      onPressed: controller.text.trim().isEmpty
                          ? null
                          : () {
                              onSubmit(controller.text.trim());
                              Navigator.pop(context);
                            },
                    ),
                  ],
                )
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}