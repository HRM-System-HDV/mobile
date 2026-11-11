import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';

import 'mock_api_client.dart';

void main() {
  late MockApiClient mockApi;
  late AttendanceRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = AttendanceRepository(api: mockApi);
  });

  group('AttendanceRepository.checkIn', () {
    test('sends wifiBssid, wifiSsid and checkinTime and deserializes model', () async {
      mockApi.postJsonResponse = {
        'id': 'att-1',
        'employeeId': 'emp-101',
        'shiftId': 'shift-morning',
        'date': '15-11-2026',
        'checkIn': '08:02',
        'penaltyAmount': 0,
        'status': 'present',
      };

      final result = await repository.checkIn(
        employeeId: 'emp-101',
        shiftId: 'shift-morning',
        wifiSsid: 'Company_WiFi',
        wifiBssid: '00:11:22:33:44:55',
        checkinTime: '08:02',
      );

      expect(result.id, 'att-1');
      expect(result.employeeId, 'emp-101');
      expect(result.shiftId, 'shift-morning');
      expect(result.checkIn, '08:02');
      expect(result.status, 'present');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/attendance/checkin');
      expect(req.payload?['employeeId'], 'emp-101');
      expect(req.payload?['shiftId'], 'shift-morning');
      expect(req.payload?['wifiSsid'], 'Company_WiFi');
      expect(req.payload?['wifiBssid'], '00:11:22:33:44:55');
      expect(req.payload?['checkinTime'], '08:02');
    });

    test('omits optional wifi parameters when null', () async {
      mockApi.postJsonResponse = {
        'id': 'att-2',
        'employeeId': 'emp-102',
        'shiftId': 'shift-evening',
        'date': '15-11-2026',
        'status': 'present',
      };

      await repository.checkIn(
        employeeId: 'emp-102',
        shiftId: 'shift-evening',
      );

      final req = mockApi.requests.first;
      expect(req.payload?.containsKey('wifiSsid'), false);
      expect(req.payload?.containsKey('wifiBssid'), false);
      expect(req.payload?.containsKey('checkinTime'), false);
    });

    test('propagates ApiException on checkIn failure', () async {
      mockApi.postJsonHandler = (path, payload) {
        throw const ApiException('INVALID_BSSID', 'BSSID Wi-Fi không hợp lệ', 400);
      };

      expect(
        () => repository.checkIn(employeeId: 'emp-1', shiftId: 'shift-1'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_BSSID')),
      );
    });
  });

  group('AttendanceRepository.checkOut', () {
    test('sends checkout payload and deserializes model', () async {
      mockApi.postJsonResponse = {
        'id': 'att-1',
        'employeeId': 'emp-101',
        'shiftId': 'shift-morning',
        'date': '15-11-2026',
        'checkIn': '08:00',
        'checkOut': '17:05',
        'penaltyAmount': 0,
        'status': 'present',
      };

      final result = await repository.checkOut(
        attendanceId: 'att-1',
        employeeId: 'emp-101',
        shiftId: 'shift-morning',
        checkoutTime: '17:05',
      );

      expect(result.id, 'att-1');
      expect(result.checkOut, '17:05');

      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/attendance/checkout');
      expect(req.payload?['attendanceId'], 'att-1');
      expect(req.payload?['checkoutTime'], '17:05');
    });
  });

  group('AttendanceRepository.getConfig', () {
    test('returns config data when response has data envelope', () async {
      mockApi.getJsonResponse = {
        'data': {'gracePeriodMinutes': 10, 'requireWifi': true}
      };

      final config = await repository.getConfig();
      expect(config['gracePeriodMinutes'], 10);
      expect(config['requireWifi'], true);
    });

    test('returns empty map on error without throwing', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('SERVER_ERROR', 'Lỗi', 500);
      };

      final config = await repository.getConfig();
      expect(config, isEmpty);
    });
  });

  group('AttendanceRepository.getAttendance', () {
    test('queries /api/attendance with employeeId and date', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'att-1',
          'employeeId': 'emp-101',
          'shiftId': 's-1',
          'date': '15-11-2026',
          'penaltyAmount': 50000,
          'penaltyNote': 'Đi muộn 15 phút',
          'status': 'late',
        }
      ];

      final list = await repository.getAttendance(employeeId: 'emp-101', date: '2026-11-15');

      expect(list.length, 1);
      expect(list.first.penaltyAmount, 50000.0);
      expect(list.first.status, 'late');
      expect(list.first.penaltyNote, 'Đi muộn 15 phút');

      final req = mockApi.requests.first;
      expect(req.path, '/api/attendance');
      expect(req.query?['employeeId'], 'emp-101');
      expect(req.query?['date'], '2026-11-15');
    });
  });
}
