import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Thông tin thiết bị thật gửi kèm mọi request qua header x-device-*.
/// Header HTTP chỉ chứa ASCII nên giá trị được encode URI, backend tự giải mã.
class DeviceInfoService {
  static Map<String, String> _headers = {};

  static Map<String, String> get headers => _headers;

  static Future<void> init() async {
    try {
      final plugin = DeviceInfoPlugin();
      String name;
      String type;
      String os;
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final userName = info.name.trim();
        final model = info.model;
        name = userName.isNotEmpty ? userName : model;
        type = model.toLowerCase().contains('ipad') ? 'tablet' : 'phone';
        os = '${info.systemName} ${info.systemVersion} - HRM Mobile';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        name = '${info.brand} ${info.model}'.trim();
        type = 'phone';
        os = 'Android ${info.version.release} - HRM Mobile';
      } else {
        name = Platform.localHostname;
        type = 'desktop';
        os = Platform.operatingSystem;
      }
      _headers = {
        'x-device-name': Uri.encodeComponent(name),
        'x-device-type': type,
        'x-os-info': Uri.encodeComponent(os.trim()),
      };
    } catch (_) {
      _headers = {};
    }
  }
}