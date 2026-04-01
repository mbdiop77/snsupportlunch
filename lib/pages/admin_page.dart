import 'dart:async';
import 'package:flutter/material.dart';
import 'tab/dashboardpage.dart';
import 'tab/weeklywenuadmin.dart';
import '../providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'tab/affiche_suggestions.dart';
import 'tab/settings.dart';
import 'tab/history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';
import '../services/auth_service.dart';

class AdminPage extends StatefulWidget {
  final Map employee;

  const AdminPage({super.key, required this.employee});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  int suggestionsCount = 0;

  final supabase = Supabase.instance.client;

  Timer? _timer;

  String qrData = "";

  late final RealtimeChannel commentsChannel;

  @override
  void initState() {
    super.initState();

    generateQR();

    /// génération automatique toutes les 30 secondes
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => generateQR(),
    );

    loadSuggestionsCount();

    /// realtime suggestions
    commentsChannel = supabase
        .channel('comments_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comment',
          callback: (payload) {
            loadSuggestionsCount();
          },
        )
        .subscribe();
  }

  /// génération QR
  void generateQR() {

    final matricule = widget.employee['matricule'];

    if (!mounted) return;

    setState(() {
      qrData = QrService.generateQR(matricule);
    });
  }

  Future<void> loadSuggestionsCount() async {

    final data = await supabase
        .from('comment')
        .select('id')
        .eq('is_read', false);

    if (!mounted) return;

    setState(() {
      suggestionsCount = data.length;
    });
  }

  @override
  void dispose() {
    commentsChannel.unsubscribe();
    _timer?.cancel();
    super.dispose();
  }

  /// =========================
  /// UI
  /// =========================

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(

      length: 5,

      child: Scaffold(

        appBar: AppBar(

          elevation: 20,

          backgroundColor: Colors.blue,

          iconTheme: const IconThemeData(color: Colors.black),

          title: Row(

            children: [

              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.person, color: Colors.black),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  "${widget.employee['prenom'] ?? ''} "
                  "${widget.employee['nom'] ?? ''} (Admin)",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          actions: [

            /// bouton QR
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: "My dmin QR",
              onPressed: () {
                showAdminQR(context);
              },
            ),

            /// logout
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Colors.black),
              tooltip: "Logout",
             onPressed: () async {
              final session = context.read<SessionProvider>();
              await AuthService().logout(); // SSO
              await session.logout();       // local
            }
            ),
          ],

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),

            child: Column(

              children: [

                Container(height: 5, color: Colors.white),

                TabBar(

                  labelStyle: const TextStyle(fontSize: 12),

                  tabs: [

                    const Tab(
                        icon: Icon(Icons.dashboard, size: 18),
                        text: "Dashboard"),

                    const Tab(
                        icon: Icon(Icons.calendar_month, size: 18),
                        text: "Planification du menu"),

                    const Tab(
                        icon: Icon(Icons.history, size: 18),
                        text: "Historique"),

                    Tab(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [

                          const Icon(Icons.message, size: 18),

                          if (suggestionsCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  suggestionsCount > 99
                                      ? "99+"
                                      : suggestionsCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      text: "Suggestion",
                    ),

                    const Tab(
                        icon: Icon(Icons.settings, size: 18),
                        text: "Settings"),
                  ],
                ),
              ],
            ),
          ),
        ),

        body: TabBarView(

          children: [

            const DashboardPage(),

            const WeeklyMenuAdmin(),

            const HistoryPage(),

            const SuggestionsPage(),

            SettingPage(currentAdmin: widget.employee),

          ],
        ),
      ),
    );
  }

  /// =========================
  /// Dialog QR dynamique
  /// =========================

  void showAdminQR(BuildContext context) {

    showDialog(

      context: context,

      builder: (context) {

        return Dialog(

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          child: StatefulBuilder(

            builder: (context, setStateDialog) {

              /// rafraîchir le dialog toutes les secondes
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) {
                  setStateDialog(() {});
                }
              });

              return Container(

                width: 240,

                padding: const EdgeInsets.all(20),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Text(
                      "ADMIN QR",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 20),

                    QrImageView(
                      data: qrData,
                      size: 200,
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}