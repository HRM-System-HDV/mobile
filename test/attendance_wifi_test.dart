import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/services/attendance_wifi.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'repositories/mock_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const network = MethodChannel('dev.fluttercommunity.plus/network_info');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  String? bssid;
  bool granted = true;
  setUp(() {
    bssid = 'AA:BB:CC:DD:EE:FF';
    granted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            permissions, (call) async => {5: granted ? 1 : 0});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(network,
            (call) async => call.method == 'wifiBSSID' ? bssid : '"Office"');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(network, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  test('Vào/ra ca đều đọc Wi-Fi hiện tại mỗi lần và gửi object wifi', () async {
    final api = MockApiClient()..postJsonResponse = <String, dynamic>{};
    final repo = AttendanceRepository(api: api);
    await repo.checkInWithDeviceWifi(employeeId: 'employee', shiftId: 'shift');
    expect(api.requests.last.payload!['wifi'],
        {'ssid': 'Office', 'bssid': 'aa:bb:cc:dd:ee:ff'});
    bssid = '11:22:33:44:55:66';
    await repo.checkOutWithDeviceWifi(employeeId: 'employee', shiftId: 'shift');
    expect(api.requests.last.path, '/api/attendance/checkout');
    expect(api.requests.last.payload!['wifi']['bssid'], bssid);
  });
  test('Không đọc được Wi-Fi thì không gửi request chấm công', () async {
    final api = MockApiClient();
    final repo = AttendanceRepository(api: api);
    for (final value in [null, '', '00:00:00:00:00:00', '02:00:00:00:00:00']) {
      bssid = value;
      await expectLater(
          repo.checkInWithDeviceWifi(employeeId: 'employee', shiftId: 'shift'),
          throwsA(isA<ApiException>()));
    }
    expect(api.requests, isEmpty);
  });
  test('Từ chối quyền vị trí có thông báo rõ ràng', () async {
    granted = false;
    await expectLater(
        AttendanceWifi().read(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'WIFI_PERMISSION')));
  });
}
