import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
//import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

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
      return sha1.convert(utf8.encode(info.deviceId)).toString();
    }

    if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return sha1.convert(utf8.encode(info.systemGUID ?? "mac")).toString();
    }

    if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return sha1.convert(utf8.encode(info.machineId ?? "linux")).toString();
    }

    return sha1.convert(utf8.encode("unknown_device")).toString();
  }

  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

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
      return info.prettyName;
    }

    return "Unknown Device";
  }

  Future<void> upsertDevice({
    required SupabaseClient supabase,
    required String employeeMatricule,
  }) async {

    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();

    final devices = await supabase
        .from('devices')
        .select()
        .eq('employee_matricule', employeeMatricule)
        .order('last_seen', ascending: true);

    if (devices.length >= 3) {
      final oldest = devices.first['device_id'];

      await supabase
          .from('devices')
          .delete()
          .eq('employee_matricule', employeeMatricule)
          .eq('device_id', oldest);
    }

    await supabase.from('devices').upsert({
      'employee_matricule': employeeMatricule,
      'device_id': deviceId,
      'device_name': deviceName,
      'last_seen': DateTime.now().toIso8601String(),
      'is_active': true,
    }, onConflict: 'employee_matricule,device_id');
  }
}