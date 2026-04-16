import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/session_provider.dart';

class DeviceRealtime {
  final SupabaseClient supabase;

  DeviceRealtime({required this.supabase});

  /// 🔹 Abonne le device courant pour déconnexion forcée
  void subscribeDevice(String deviceId, BuildContext context) {
    debugPrint("🚀 subscribeDevice called for deviceId: $deviceId");

    final channelName = 'realtime:devices:$deviceId';
    debugPrint("📡 Creating channel: $channelName");

    final channel = supabase.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'devices',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'device_id',
        value: deviceId,
      ),
      callback: (payload, [ref]) {
        debugPrint("📨 Realtime payload received for device $deviceId: ${payload.newRecord}");

        final newData = payload.newRecord;

    debugPrint("📨 Admin Realtime payload received: $newData");

        final isActive = newData['is_active'] as bool?;
        debugPrint("🔹 Device $deviceId is_active = $isActive");

        if (isActive == false) {
          if (context.mounted) {
            debugPrint("🔥 Device $deviceId will be force logged out");
            context.read<SessionProvider>().forceLogout();
          } else {
            debugPrint("⚠️ Context not mounted, cannot logout");
          }
        }
      },
    );

    channel.subscribe((status, [error]) {
      debugPrint("📢 Channel status for $deviceId: $status, error: $error");
    });
  }

  /// 🔹 Abonne tous les devices pour admin (logs et debug)
  void subscribeAllDevices() {
    debugPrint("🚀 subscribeAllDevices called");

    final channelName = 'realtime:devices';
    debugPrint("📡 Creating admin channel: $channelName");

    final channel = supabase.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'devices',
      callback: (payload, [ref]) {
        debugPrint("📨 Admin Realtime payload received: ${payload.newRecord}");

        final newData = payload.newRecord;

    debugPrint("📨 Admin Realtime payload received: $newData");

        final deviceId = newData['device_id'];
        final isActive = newData['is_active'] as bool?;
        debugPrint("🔹 Device $deviceId is_active = $isActive");

        if (isActive == false) {
          debugPrint("❌ Device $deviceId has been deactivated");
        }
      },
    );

    channel.subscribe((status, [error]) {
      debugPrint("📢 Admin channel status: $status, error: $error");
    });
  }
}




class AppInitializer extends StatefulWidget {
  final Widget child;
  const AppInitializer({super.key,required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
 // final deviceService = DeviceService();
  late DeviceRealtime deviceRealtime;

  @override
  void initState() {
    super.initState();
    initDeviceRealtime();
  }

  Future<void> initDeviceRealtime() async {
   // final deviceId = await deviceService.getDeviceId();

    if (!mounted) return;

    deviceRealtime = DeviceRealtime(
      supabase: Supabase.instance.client,
    );

  //  deviceRealtime.subscribeDevice(deviceId, context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}