import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';

import 'mock_api_client.dart';

/// Bản ghi `attendances` thật: workDate ISO, checkIn/checkOut là mốc thời gian
/// ISO có múi giờ, penaltyAmount/earnedSalary là Decimal nên về dạng chuỗi.
Map<String, dynamic> _attendanceRow({
  String id = 'att-1',
  String employeeId = 'emp-101',
  String shiftId = 'shift-morning',
  String? checkIn = '2026-11-15T01:02:00.000Z',
  String? checkOut,
  Object penaltyAmount = '0',
  String? penaltyNote,
  String status = 'present',
}) =>
    {
      'id': id,
      'employeeId': employeeId,
      'shiftId': shiftId,
      'workDate': '2026-11-15',
      'checkIn': checkIn,
      'checkOut': checkOut,
      'penaltyAmount': penaltyAmount,
      'penaltyNote': penaltyNote,
      'earnedSalary': '150000',
      'workedSeconds': 3600,
      'status': status,
    };

void main() {
  late MockApiClient mockApi;
  late AttendanceRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = AttendanceRepository(api: mockApi);
  });

  group('AttendanceRepository.checkIn', () {
    test('gửi đúng bộ khóa employeeId + shiftId + wifi (object)', () async {
      mockApi.postJsonResponse = _attendanceRow();

      final result = await repository.checkIn(
        employeeId: 'emp-101',
        shiftId: 'shift-morning',
        wifiSsid: 'Company_WiFi',
        wifiBssid: '00:11:22:33:44:55',
      );

      expect(result.id, 'att-1');
      expect(result.employeeId, 'emp-101');
      expect(result.shiftId, 'shift-morning');
      expect(result.workDate, '2026-11-15');
      expect(result.checkIn, '2026-11-15T01:02:00.000Z');
      expect(result.status, 'present');

      final req = mockApi.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/attendance/checkin');
      expect(req.payload?.keys.toSet(), {'employeeId', 'shiftId', 'wifi'});
      expect(req.payload?['employeeId'], 'emp-101');
      expect(req.payload?['shiftId'], 'shift-morning');
      expect(req.payload?['wifi'], {
        'ssid': 'Company_WiFi',
        'bssid': '00:11:22:33:44:55',
      });
    });

    test('không gửi checkinTime hay wifiSsid/wifiBssid rời (backend trả 400)', () async {
      mockApi.postJsonResponse = _attendanceRow();

      await repository.checkIn(employeeId: 'emp-102', shiftId: 'shift-evening');

      final payload = mockApi.requests.single.payload!;
      expect(payload.containsKey('checkinTime'), isFalse);
      expect(payload.containsKey('wifiSsid'), isFalse);
      expect(payload.containsKey('wifiBssid'), isFalse);
      expect(payload['wifi'], isEmpty);
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
    test('gửi employeeId + shiftId + wifi, không gửi attendanceId/checkoutTime', () async {
      mockApi.postJsonResponse = _attendanceRow(
        id: 'att-9',
        employeeId: 'emp-55',
        shiftId: 'shift-row-9',
        checkIn: '2026-11-15T00:40:00.000Z',
        checkOut: '2026-11-15T10:05:00.000Z',
        penaltyAmount: '30000',
        status: 'late_early_leave',
      );

      final result = await repository.checkOut(
        employeeId: 'emp-55',
        shiftId: 'shift-row-9',
        wifiBssid: 'AA:BB:CC:DD:EE:FF',
      );

      expect(result.status, 'late_early_leave');
      expect(result.checkOut, '2026-11-15T10:05:00.000Z');
      // Decimal trả về dạng chuỗi vẫn phải đọc được.
      expect(result.penaltyAmount, 30000.0);
      expect(result.earnedSalary, 150000.0);
      expect(result.workedSeconds, 3600.0);

      final req = mockApi.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/attendance/checkout');
      expect(req.payload?.keys.toSet(), {'employeeId', 'shiftId', 'wifi'});
      expect(req.payload?['employeeId'], 'emp-55');
      expect(req.payload?['shiftId'], 'shift-row-9');
      expect(req.payload?['wifi'], {'bssid': 'AA:BB:CC:DD:EE:FF'});
    });

    test('manager chốt khác chi nhánh: message backend 403 được nổi lên', () async {
      mockApi.postJsonHandler = (path, payload) {
        throw const ApiException(
          'FORBIDDEN',
          'Nhân viên không thuộc chi nhánh được quản lý',
          403,
        );
      };

      await expectLater(
        repository.checkOut(employeeId: 'emp-1', shiftId: 'shift-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message',
                  'Nhân viên không thuộc chi nhánh được quản lý'),
        ),
      );
    });

    test('staff tự chốt quá cửa sổ: message backend 400 được nổi lên', () async {
      mockApi.postJsonHandler = (path, payload) {
        throw const ApiException(
          'VALIDATION_ERROR',
          'Ca đã hết hạn checkout, vui lòng chấm công ca khác hoặc gửi đơn',
          400,
        );
      };

      await expectLater(
        repository.checkOut(employeeId: 'emp-1', shiftId: 'shift-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.code, 'code', 'VALIDATION_ERROR'),
        ),
      );
    });
  });

  group('AttendanceRepository.getConfig', () {
    test('trả đúng bản đồ cấu hình vì api_client đã bóc envelope', () async {
      mockApi.getJsonResponse = {
        'gracePeriodMinutes': 10,
        'checkoutWindowMinutes': 60,
        'allowDoubleCheckin': false,
      };

      final config = await repository.getConfig();
      expect(config['gracePeriodMinutes'], 10);
      expect(config['checkoutWindowMinutes'], 60);
      expect(config['allowDoubleCheckin'], false);
    });

    test('repository không bóc .data lần hai', () async {
      mockApi.getJsonResponse = {
        'data': {'gracePeriodMinutes': 5},
      };

      final config = await repository.getConfig();
      expect(config.containsKey('data'), isTrue);
    });

    test('ném lỗi khi đọc cấu hình thất bại (không trả {} như thể chưa cấu hình)', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('SERVER_ERROR', 'Lỗi', 500);
      };

      // Lỗi mạng/403 phải nổ lên để tầng trên báo cho người dùng, không được
      // lặng lẽ trả cấu hình rỗng (màn sẽ dùng mặc định 5/60 như thật).
      await expectLater(
        repository.getConfig(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('AttendanceRepository.getAttendance', () {
    test('query theo workDate/month/branchId, không dùng date/branchSlug', () async {
      mockApi.getJsonResponse = [
        _attendanceRow(
          id: 'att-9',
          penaltyAmount: '50000',
          penaltyNote: 'Đi muộn 15 phút',
          status: 'late',
        ),
      ];

      final list = await repository.getAttendance(
        employeeId: 'emp-101',
        workDate: '2026-11-15',
        month: '2026-11',
        branchId: 'b-1',
      );

      expect(list.length, 1);
      expect(list.first.workDate, '2026-11-15');
      expect(list.first.penaltyAmount, 50000.0);
      expect(list.first.status, 'late');
      expect(list.first.penaltyNote, 'Đi muộn 15 phút');

      final req = mockApi.requests.single;
      expect(req.path, '/api/attendance');
      expect(req.query?['employeeId'], 'emp-101');
      expect(req.query?['workDate'], '2026-11-15');
      expect(req.query?['month'], '2026-11');
      expect(req.query?['branchId'], 'b-1');
      expect(req.query?.containsKey('date'), isFalse);
      expect(req.query?.containsKey('branchSlug'), isFalse);
    });

    test('bỏ qua tham số null hoặc rỗng', () async {
      mockApi.getJsonResponse = [];

      await repository.getAttendance(employeeId: '', branchId: null);

      expect(mockApi.requests.single.query, isEmpty);
    });
  });
}
