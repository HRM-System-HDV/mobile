import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/api_client.dart';

/// Chỉ đọc mạng đang kết nối; cấu hình chi nhánh không phải bằng chứng Wi-Fi.
class AttendanceWifi {
  Future<Map<String, String>> read() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        throw const ApiException('WIFI_PERMISSION',
            'Vui lòng cấp quyền vị trí để xác minh Wi-Fi chấm công', 400);
      }
    }
    try {
      final info = NetworkInfo();
      final bssid = (await info.getWifiBSSID())?.trim().toLowerCase();
      final ssid = (await info.getWifiName())?.replaceAll('"', '').trim();
      if (bssid == null ||
          !RegExp(r'^(?:[0-9a-f]{2}:){5}[0-9a-f]{2}$').hasMatch(bssid) ||
          bssid == '00:00:00:00:00:00' ||
          bssid == '02:00:00:00:00:00') {
        throw const ApiException(
            'WIFI_UNAVAILABLE',
            'Không đọc được Wi-Fi hiện tại. Hãy kết nối Wi-Fi chi nhánh, bật vị trí và thử lại',
            400);
      }
      return {
        'bssid': bssid,
        if (ssid != null && ssid.isNotEmpty && ssid != '<unknown ssid>')
          'ssid': ssid
      };
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
          'WIFI_UNAVAILABLE',
          'Không đọc được Wi-Fi hiện tại. Kiểm tra kết nối và quyền vị trí',
          400);
    }
  }
}
