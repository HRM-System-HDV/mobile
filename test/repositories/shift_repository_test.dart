import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/schedule/shift_repository.dart';

import 'mock_api_client.dart';

void main() {
  late MockApiClient mockApi;
  late ShiftRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = ShiftRepository(api: mockApi);
  });

  group('ShiftRepository.getShifts', () {
    test('đọc workDate/templateId/status kèm attendance, attendanceState, canCheckout', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'shift-1',
          'employeeId': 'emp-101',
          'templateId': 'tpl-1',
          'workDate': '2026-11-15',
          'scheduledStart': '08:00',
          'scheduledEnd': '12:00',
          'status': 'đang làm',
          'note': 'Trực sáng',
          'attendance': {
            'id': 'att-1',
            'employeeId': 'emp-101',
            'shiftId': 'shift-1',
            'workDate': '2026-11-15',
            'checkIn': '2026-11-15T00:40:00.000Z',
            'checkOut': null,
            'penaltyAmount': '0',
            'status': 'present',
          },
          'attendanceState': 'working',
          'canCheckout': true,
        },
        {
          'id': 'shift-2',
          'employeeId': 'emp-102',
          'templateId': 'tpl-2',
          'workDate': '2026-11-16',
          'scheduledStart': '',
          'scheduledEnd': '',
          'status': 'đã hủy',
          'attendance': null,
          'attendanceState': 'not_started',
          'canCheckout': false,
        },
      ];

      final shifts = await repository.getShifts(
        branchId: 'b-1',
        employeeId: 'emp-101',
        workDate: '15/11/2026',
      );

      expect(shifts.length, 2);
      expect(shifts[0].id, 'shift-1');
      expect(shifts[0].employeeId, 'emp-101');
      expect(shifts[0].templateId, 'tpl-1');
      expect(shifts[0].workDate, '2026-11-15');
      expect(shifts[0].status, 'đang làm');
      expect(shifts[0].timeLabel, '08:00 - 12:00');
      expect(shifts[0].attendanceState, 'working');
      expect(shifts[0].canCheckout, isTrue);
      expect(shifts[0].checkIn, '2026-11-15T00:40:00.000Z');
      expect(shifts[0].attendance?.penaltyAmount, 0.0);

      expect(shifts[1].attendance, isNull);
      expect(shifts[1].canCheckout, isFalse);
      expect(shifts[1].isCancelled, isTrue);
      expect(shifts[1].timeLabel, '—');

      final req = mockApi.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/shifts');
      expect(req.query?['branchId'], 'b-1');
      expect(req.query?['employeeId'], 'emp-101');
      // Backend chỉ nhận ngày dạng YYYY-MM-DD.
      expect(req.query?['workDate'], '2026-11-15');
      expect(req.query?.containsKey('branchSlug'), isFalse);
      expect(req.query?.containsKey('date'), isFalse);
    });

    test('lọc theo tháng YYYY-MM', () async {
      mockApi.getJsonResponse = [];

      await repository.getShifts(month: '2026-11');

      expect(mockApi.requests.single.query, {'month': '2026-11'});
    });

    test('handles empty or non-list response gracefully', () async {
      mockApi.getJsonResponse = null;
      final shifts = await repository.getShifts();
      expect(shifts, isEmpty);
    });

    test('propagates ApiException when API fails', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('FORBIDDEN', 'Không có quyền truy cập', 403);
      };

      expect(
        () => repository.getShifts(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });

  group('ShiftRepository.createShift & updateShift & deleteShift', () {
    test('createShift chỉ gửi employeeId, templateId, workDate, note', () async {
      mockApi.postJsonResponse = {
        'id': 'new-shift',
        'employeeId': 'emp-101',
        'templateId': 'tpl-3',
        'workDate': '2026-11-16',
        'scheduledStart': '13:00',
        'scheduledEnd': '17:00',
        'status': 'đang làm',
        'attendance': null,
        'attendanceState': 'not_started',
        'canCheckout': false,
      };

      final shift = await repository.createShift(
        employeeId: 'emp-101',
        templateId: 'tpl-3',
        workDate: '16/11/2026',
        note: 'Trực chiều',
      );

      expect(shift.id, 'new-shift');
      expect(shift.templateId, 'tpl-3');
      expect(shift.workDate, '2026-11-16');

      final req = mockApi.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shifts');
      expect(req.payload?.keys.toSet(), {'employeeId', 'templateId', 'workDate', 'note'});
      expect(req.payload?['workDate'], '2026-11-16');
    });

    test('updateShift puts only allowed keys, status là "đã hủy"', () async {
      mockApi.putJsonResponse = {'success': true};

      await repository.updateShift('shift-99', status: 'đã hủy');

      final req = mockApi.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/shifts/shift-99');
      expect(req.payload, {'status': 'đã hủy'});
    });

    test('ApiShiftModel.toJson không chứa khóa backend không nhận', () async {
      const shift = ApiShiftModel(
        id: 'shift-1',
        employeeId: 'emp-101',
        workDate: '2026-11-15',
        templateId: 'tpl-1',
        scheduledStart: '08:00',
        scheduledEnd: '12:00',
        status: 'đang làm',
      );

      expect(shift.toJson().keys.toSet(),
          {'employeeId', 'templateId', 'workDate', 'status'});
      expect(shift.toJson()['workDate'], '2026-11-15');
    });

    test('deleteShift sends DELETE to /api/shifts/:id', () async {
      await repository.deleteShift('shift-99');

      expect(mockApi.requests.single.method, 'DELETE');
      expect(mockApi.requests.single.path, '/api/shifts/shift-99');
    });
  });

  group('ShiftRepository.assignShift & registration', () {
    test('assignShift posts employeeId to /api/shifts/:id/assign', () async {
      await repository.assignShift('shift-1', employeeId: 'emp-202');

      expect(mockApi.requests.single.method, 'POST');
      expect(mockApi.requests.single.path, '/api/shifts/shift-1/assign');
      expect(mockApi.requests.single.payload?['employeeId'], 'emp-202');
    });

    test('registerShift gửi employeeId + templateId + registerDate (UUID + ISO)', () async {
      await repository.registerShift(
        employeeId: 'emp-101',
        templateId: 'tpl-3',
        registerDate: '20/11/2026',
      );

      final req = mockApi.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shifts/register');
      expect(req.payload?.keys.toSet(), {'employeeId', 'templateId', 'registerDate'});
      expect(req.payload?['templateId'], 'tpl-3');
      expect(req.payload?['registerDate'], '2026-11-20');
    });

    test('hủy nguyện vọng là DELETE /api/shifts/registrations/:id', () async {
      await repository.deleteRegistration('reg-5');

      expect(mockApi.requests.single.method, 'DELETE');
      expect(mockApi.requests.single.path, '/api/shifts/registrations/reg-5');
    });

    test('getRegistrations query employeeId + branchId + registerDate', () async {
      mockApi.getJsonResponse = [
        {'id': 'reg-1', 'employeeId': 'emp-101', 'templateId': 'tpl-3'}
      ];

      final list = await repository.getRegistrations(
        employeeId: 'emp-101',
        branchId: 'b-1',
        registerDate: '2026-11-20',
      );

      expect(list.length, 1);
      expect(list.first['id'], 'reg-1');

      final req = mockApi.requests.single;
      expect(req.path, '/api/shifts/registrations');
      expect(req.query?['employeeId'], 'emp-101');
      expect(req.query?['branchId'], 'b-1');
      expect(req.query?['registerDate'], '2026-11-20');
      expect(req.query?.containsKey('branchSlug'), isFalse);
    });
  });

  group('ShiftRepository templates', () {
    test('getTemplates, createTemplate, updateTemplate, deleteTemplate', () async {
      mockApi.getJsonResponse = [
        {'id': 'tpl-1', 'templateCode': 'CA-S', 'name': 'Ca Sáng', 'startTime': '08:00', 'endTime': '12:00'}
      ];
      final templates = await repository.getTemplates();
      expect(templates.length, 1);
      expect(templates.first['id'], 'tpl-1');

      mockApi.postJsonResponse = {'id': 'tpl-2', 'templateCode': 'CA-T', 'name': 'Ca Tối'};
      final created = await repository.createTemplate({
        'templateCode': 'CA-T',
        'name': 'Ca Tối',
        'startTime': '17:00',
        'endTime': '21:00',
      });
      expect(created['id'], 'tpl-2');
      expect(mockApi.requests.last.payload?.keys.toSet(),
          {'templateCode', 'name', 'startTime', 'endTime'});

      await repository.updateTemplate('tpl-2', {'name': 'Ca Đêm'});
      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/shift-templates/tpl-2');

      await repository.deleteTemplate('tpl-2');
      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/shift-templates/tpl-2');
    });
  });
}
