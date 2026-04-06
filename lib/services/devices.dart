import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {

  /// Génère un ID unique pour chaque appareil
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      final raw = webInfo.userAgent ?? "web_device";
      return sha1.convert(utf8.encode(raw)).toString();
    }

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      final raw = "${info.brand}-${info.model}-${info.id}";
      return sha1.convert(utf8.encode(raw)).toString();
    }

    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      final raw = info.identifierForVendor ?? "ios_device";
      return sha1.convert(utf8.encode(raw)).toString();
    }

    if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      final raw = info.deviceId;
      return sha1.convert(utf8.encode(raw)).toString();
    }

    if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      final raw = info.systemGUID ?? "mac_device";
      return sha1.convert(utf8.encode(raw)).toString();
    }

    if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      final raw = info.machineId ?? "linux_device";
      return sha1.convert(utf8.encode(raw)).toString();
    }

    return sha1.convert(utf8.encode("unknown_device")).toString();
  }

  /// Nom lisible de l'appareil
  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;

      return "${webInfo.browserName.name} (${webInfo.platform ?? 'web'})";
    }else{
      
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return "${info.brand} ${info.model}";
    }

    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.name;
    }

    if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return info.computerName;
    }

    if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return info.computerName;
    }

    if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return info.prettyName ;
    }

    return "Unknown Device";
  }

    }

  /// Enregistre ou met à jour un device admin
  Future<void> upsertDevice({
    required SupabaseClient supabase,
    required String employeeMatricule,
  }) async {

    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();

    debugPrint("Device ID: $deviceId");
    debugPrint("Device Name: $deviceName");

    final devices = await supabase
        .from('devices')
        .select()
        .eq('employee_matricule', employeeMatricule)
        .order('last_seen', ascending: true);

    /// Limite à 3 appareils
    if (devices.length >= 3) {
      final oldest = devices.first['device_id'];

      await supabase
          .from('devices')
          .delete()
          .eq('employee_matricule', employeeMatricule)
          .eq('device_id', oldest);

   //   debugPrint("Ancien device supprimé");
    }

    /// Insert ou update
    await supabase.from('devices').upsert(
      {
        'employee_matricule': employeeMatricule,
        'device_id': deviceId,
        'device_name': deviceName,
        'last_seen': DateTime.now().toIso8601String(),
        'is_active': true, 
      },
      onConflict: 'employee_matricule,device_id',
    );

    //debugPrint("Device enregistré $deviceName");
  }
}