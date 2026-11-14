import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/network/api_client.dart';
import 'src/core/services/device_info.dart';
import 'src/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotifier.instance.init();
  await DeviceInfoService.init();
  ApiClient.setDeviceHeaders(DeviceInfoService.headers);
  runApp(const HRMApp());
}