import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'package:mobile/src/features/home/home.dart';
import 'package:mobile/src/features/wifi_config/wifi_config_repository.dart';

import 'repositories/mock_api_client.dart';

/// `toSafeUser` của identity-service không còn trả `roleTitle`, nên UserModel
/// chỉ dựng được các trường thật sự có trên hợp đồng.
UserModel _user() => const UserModel(
      id: 'emp-challenger-01',
      name: 'Nguyen Van Challenger',
      email: 'challenger@company.com',
      role: 'staff',
    );

/// integration-service khai báo wifiConfig.branchId là UUID bắt buộc
/// (`contentFields.wifiConfig`), không còn tên chi nhánh dạng `branch`.
const _branchId = '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const networkChannel = MethodChannel('dev.fluttercommunity.plus/network_info');

  group('Empirical Challenge 1: AttendanceRepository checkIn payload behavior', () {
    late MockApiClient mockApi;
    late AttendanceRepository repo;

    setUp(() {
      mockApi = MockApiClient();
      repo = AttendanceRepository(api: mockApi);
    });

    test('Case 1.1: wifi identifiers are null -> wifi object is empty, no extra key leaks', () async {
      mockApi.postJsonResponse = {
        'id': 'att-null-bssid',
        'employeeId': 'emp-challenger-01',
        'shiftId': 'shift-morning',
        'workDate': '2026-11-11',
        'checkIn': '2026-11-11T08:00:00.000Z',
        'status': 'present',
      };

      final result = await repo.checkIn(
        employeeId: 'emp-challenger-01',
        shiftId: 'shift-morning',
        wifiSsid: null,
        wifiBssid: null,
      );

      expect(result.id, 'att-null-bssid');
      expect(result.workDate, '2026-11-11');
      expect(mockApi.requests.length, 1);
      expect(mockApi.requests.first.path, '/api/attendance/checkin');
      final payload = mockApi.requests.first.payload!;
      // WorkService gọi fields(payload, ["employeeId", "shiftId", "wifi"]): đúng
      // ba khóa, khóa thừa là 400 "Thuộc tính không hỗ trợ".
      expect(payload.keys.toSet(), {'employeeId', 'shiftId', 'wifi'});
      expect(payload['wifi'], isEmpty,
          reason: 'wifi là object {ssid,bssid}; không có ssid/bssid thì rỗng');
      expect(payload['employeeId'], 'emp-challenger-01');
      expect(payload['shiftId'], 'shift-morning');
      // Giờ vào do server tính (Time.now), client gửi lên là key thừa -> 400.
      expect(payload.containsKey('checkinTime'), isFalse);
      expect(payload.containsKey('attendanceId'), isFalse);
      expect(payload.containsKey('wifiSsid'), isFalse,
          reason: 'wifi phải nằm trong object, không phải hai khóa rời');
      expect(payload.containsKey('wifiBssid'), isFalse);
    });

    test('Case 1.2: wifi identifiers present -> sent as ONE {ssid, bssid} object', () async {
      mockApi.postJsonResponse = {
        'id': 'att-with-bssid',
        'employeeId': 'emp-challenger-01',
        'shiftId': 'shift-morning',
        'workDate': '2026-11-11',
        'checkIn': '2026-11-11T08:00:00.000Z',
        'status': 'present',
      };

      final result = await repo.checkIn(
        employeeId: 'emp-challenger-01',
        shiftId: 'shift-morning',
        wifiSsid: 'Office_Guest',
        wifiBssid: 'AA:BB:CC:DD:EE:FF',
      );

      expect(result.id, 'att-with-bssid');
      expect(mockApi.requests.length, 1);
      final payload = mockApi.requests.first.payload!;
      expect(payload.keys.toSet(), {'employeeId', 'shiftId', 'wifi'});
      expect(payload['wifi'], {
        'ssid': 'Office_Guest',
        'bssid': 'AA:BB:CC:DD:EE:FF',
      });
    });

    test('Case 1.2b: checkOut dùng đúng một object wifi, không có checkoutTime', () async {
      mockApi.postJsonResponse = {
        'id': 'att-out',
        'employeeId': 'emp-challenger-01',
        'shiftId': 'shift-evening',
        'workDate': '2026-11-11',
        'checkOut': '2026-11-11T22:05:00.000Z',
        'status': 'present',
      };

      await repo.checkOut(
        employeeId: 'emp-challenger-01',
        shiftId: 'shift-evening',
        wifiSsid: 'Office_Guest',
        wifiBssid: 'AA:BB:CC:DD:EE:FF',
      );

      final payload = mockApi.requests.first.payload!;
      expect(mockApi.requests.first.path, '/api/attendance/checkout');
      expect(payload.keys.toSet(), {'employeeId', 'shiftId', 'wifi'});
      expect(payload['wifi'], {'ssid': 'Office_Guest', 'bssid': 'AA:BB:CC:DD:EE:FF'});
      expect(payload.containsKey('checkoutTime'), isFalse);
      expect(payload.containsKey('attendanceId'), isFalse);
    });

    test('Case 1.3: Server throws ApiException (400 / 403) -> propagated correctly', () async {
      mockApi.postJsonHandler = (path, payload) {
        throw const ApiException('FORBIDDEN', 'Không được chấm công hộ', 403);
      };

      expect(
        () => repo.checkIn(employeeId: 'emp-other', shiftId: 'shift-1'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });
  });

  group('Empirical Challenge 2: Effective BSSID resolution logic stress tests', () {
    // Tests the algorithm used in home.dart:755-757:
    // final effectiveBssid = (hardwareBssid != null && hardwareBssid.isNotEmpty)
    //     ? hardwareBssid
    //     : (_wifiConfigs.isNotEmpty && _wifiConfigs.first.bssid.isNotEmpty ? _wifiConfigs.first.bssid : null);

    String? resolveEffectiveBssid(String? hardwareBssid, List<WifiConfigModel> wifiConfigs) {
      return (hardwareBssid != null && hardwareBssid.isNotEmpty)
          ? hardwareBssid
          : (wifiConfigs.isNotEmpty && wifiConfigs.first.bssid.isNotEmpty ? wifiConfigs.first.bssid : null);
    }

    test('Case 2.1: Hardware BSSID present -> takes priority over config BSSID', () {
      final configs = [
        const WifiConfigModel(id: 'w1', ssid: 'Store_WiFi', bssid: 'CONFIG:BSSID:11', branchId: _branchId, status: 'hoạt động')
      ];
      final effective = resolveEffectiveBssid('HARDWARE:BSSID:22', configs);
      expect(effective, 'HARDWARE:BSSID:22');
    });

    test('Case 2.2: Hardware BSSID is null -> falls back to branch config BSSID', () {
      final configs = [
        const WifiConfigModel(id: 'w1', ssid: 'Store_WiFi', bssid: 'CONFIG:BSSID:11', branchId: _branchId, status: 'hoạt động')
      ];
      final effective = resolveEffectiveBssid(null, configs);
      expect(effective, 'CONFIG:BSSID:11');
    });

    test('Case 2.3: Hardware BSSID is empty string -> falls back to branch config BSSID', () {
      final configs = [
        const WifiConfigModel(id: 'w1', ssid: 'Store_WiFi', bssid: 'CONFIG:BSSID:11', branchId: _branchId, status: 'hoạt động')
      ];
      final effective = resolveEffectiveBssid('', configs);
      expect(effective, 'CONFIG:BSSID:11');
    });

    test('Case 2.4: Hardware BSSID null and configs empty -> resolves to null', () {
      final effective = resolveEffectiveBssid(null, []);
      expect(effective, isNull);
    });

    test('Case 2.5: Hardware BSSID empty string and configs empty -> resolves to null', () {
      final effective = resolveEffectiveBssid('', []);
      expect(effective, isNull);
    });

    test('Case 2.6: Hardware BSSID null and config BSSID empty -> resolves to null', () {
      final configs = [
        const WifiConfigModel(id: 'w1', ssid: 'Store_WiFi', bssid: '', branchId: _branchId, status: 'hoạt động')
      ];
      final effective = resolveEffectiveBssid(null, configs);
      expect(effective, isNull);
    });
  });

  group('Empirical Challenge 3: NetworkInfo hardware Wi-Fi fallback & PlatformException handling in HomeScreen', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, null);
    });

    testWidgets('Case 3.1: NetworkInfo returns valid hardware BSSID and quoted SSID -> quotes stripped & labeled "đã nhận diện"', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'wifiBSSID') return '11:22:33:44:55:66';
        if (methodCall.method == 'wifiName') return '"HRM_Office_5G"';
        return null;
      });

      final user = _user();
      final notifier = ValueNotifier<UserModel?>(user);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: UserScope(
            notifier: notifier,
            child: HomeScreen(currentUser: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkInButton = find.text('Chấm công vào ca');
      expect(checkInButton, findsOneWidget);
      await tester.tap(checkInButton);
      await tester.pumpAndSettle();

      // Verify hardware BSSID was detected and labeled
      expect(find.textContaining('11:22:33:44:55:66 (đã nhận diện)'), findsOneWidget);
      // Verify quotes stripped from SSID
      expect(find.textContaining('HRM_Office_5G'), findsOneWidget);
      expect(find.textContaining('"HRM_Office_5G"'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Case 3.2: NetworkInfo returns "<unknown ssid>" -> converted to null / fallback', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'wifiBSSID') return '11:22:33:44:55:66';
        if (methodCall.method == 'wifiName') return '<unknown ssid>';
        return null;
      });

      final user = _user();
      final notifier = ValueNotifier<UserModel?>(user);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: UserScope(
            notifier: notifier,
            child: HomeScreen(currentUser: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkInButton = find.text('Chấm công vào ca');
      await tester.tap(checkInButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('<unknown ssid>'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Case 3.3: NetworkInfo returns null (e.g. simulator/emulator or location turned off)', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, (MethodCall methodCall) async {
        return null;
      });

      final user = _user();
      final notifier = ValueNotifier<UserModel?>(user);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: UserScope(
            notifier: notifier,
            child: HomeScreen(currentUser: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkInButton = find.text('Chấm công vào ca');
      expect(checkInButton, findsOneWidget);
      await tester.tap(checkInButton);
      await tester.pumpAndSettle();

      // Bottom sheet renders safely without crashing
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Case 3.4: NetworkInfo throws PlatformException (e.g. permission denied or missing feature)', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'User denied ACCESS_FINE_LOCATION permission',
          details: null,
        );
      });

      final user = _user();
      final notifier = ValueNotifier<UserModel?>(user);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: UserScope(
            notifier: notifier,
            child: HomeScreen(currentUser: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen must gracefully catch PlatformException in try/catch without crashing
      final checkInButton = find.text('Chấm công vào ca');
      expect(checkInButton, findsOneWidget);
      await tester.tap(checkInButton);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Case 3.5: NetworkInfo throws MissingPluginException (unsupported platform)', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(networkChannel, (MethodCall methodCall) async {
        throw MissingPluginException('No implementation found for method ${methodCall.method}');
      });

      final user = _user();
      final notifier = ValueNotifier<UserModel?>(user);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: UserScope(
            notifier: notifier,
            child: HomeScreen(currentUser: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkInButton = find.text('Chấm công vào ca');
      expect(checkInButton, findsOneWidget);
      await tester.tap(checkInButton);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
