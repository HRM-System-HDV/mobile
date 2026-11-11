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
    test('fetches and deserializes shifts with query params and toVnDate', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'shift-1',
          'employeeId': 'emp-101',
          'branchSlug': 'q1',
          'date': '2026-11-15',
          'template': 'Ca Sáng',
          'scheduledStart': '08:00',
          'scheduledEnd': '12:00',
          'status': 'scheduled',
          'note': 'Đi đúng giờ',
          'isRecurring': true,
        },
        {
          'id': 'shift-2',
          'date': '15/11/2026',
          'template': '',
          'scheduledStart': '',
          'scheduledEnd': '',
        }
      ];

      final shifts = await repository.getShifts(
        branchSlug: 'q1',
        employeeId: 'emp-101',
        date: '2026-11-15',
      );

      expect(shifts.length, 2);
      expect(shifts[0].id, 'shift-1');
      expect(shifts[0].employeeId, 'emp-101');
      expect(shifts[0].branchSlug, 'q1');
      expect(shifts[0].timeLabel, '08:00 - 12:00');
      expect(shifts[0].displayTemplate, 'Ca Sáng');
      expect(shifts[0].isRecurring, true);

      expect(shifts[1].displayTemplate, '—');
      expect(shifts[1].timeLabel, '—');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'GET');
      expect(req.path, '/api/shifts');
      expect(req.query?['branchSlug'], 'q1');
      expect(req.query?['employeeId'], 'emp-101');
      expect(req.query?['date'], '15/11/2026');
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
    test('createShift posts payload and returns created model', () async {
      mockApi.postJsonResponse = {
        'id': 'new-shift',
        'date': '16/11/2026',
        'template': 'Ca Chiều',
        'scheduledStart': '13:00',
        'scheduledEnd': '17:00',
        'status': 'scheduled',
      };

      final shift = await repository.createShift({
        'template': 'Ca Chiều',
        'date': '16/11/2026',
      });

      expect(shift.id, 'new-shift');
      expect(shift.template, 'Ca Chiều');
      expect(mockApi.requests.first.method, 'POST');
      expect(mockApi.requests.first.path, '/api/shifts');
    });

    test('updateShift puts payload to /api/shifts/:id', () async {
      mockApi.putJsonResponse = {'success': true};

      await repository.updateShift('shift-99', {'status': 'completed'});

      expect(mockApi.requests.first.method, 'PUT');
      expect(mockApi.requests.first.path, '/api/shifts/shift-99');
      expect(mockApi.requests.first.payload?['status'], 'completed');
    });

    test('deleteShift sends DELETE to /api/shifts/:id', () async {
      await repository.deleteShift('shift-99');

      expect(mockApi.requests.first.method, 'DELETE');
      expect(mockApi.requests.first.path, '/api/shifts/shift-99');
    });
  });

  group('ShiftRepository.assignShift & registration', () {
    test('assignShift posts employeeId to /api/shifts/:id/assign', () async {
      await repository.assignShift('shift-1', employeeId: 'emp-202');

      expect(mockApi.requests.first.method, 'POST');
      expect(mockApi.requests.first.path, '/api/shifts/shift-1/assign');
      expect(mockApi.requests.first.payload?['employeeId'], 'emp-202');
    });

    test('registerShift normalizes preference to DD/MM/YYYY', () async {
      await repository.registerShift(
        employeeId: 'emp-101',
        shiftId: 'shift-3',
        preference: '2026-11-20',
        branchSlug: 'q1',
      );

      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/shifts/register');
      expect(req.payload?['employeeId'], 'emp-101');
      expect(req.payload?['shiftId'], 'shift-3');
      expect(req.payload?['branchSlug'], 'q1');
      expect(req.payload?['preference'], '20/11/2026');
      expect(req.payload?['week'], '20/11/2026');
    });

    test('unregisterShift posts to /api/shifts/unregister', () async {
      await repository.unregisterShift(
        employeeId: 'emp-101',
        shiftId: 'shift-3',
        preference: '2026-11-20',
      );

      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/shifts/unregister');
      expect(req.payload?['preference'], '20/11/2026');
    });

    test('deleteRegistration sends DELETE to /api/shifts/registrations/:id', () async {
      await repository.deleteRegistration('reg-5');
      expect(mockApi.requests.first.method, 'DELETE');
      expect(mockApi.requests.first.path, '/api/shifts/registrations/reg-5');
    });

    test('getRegistrations queries /api/shifts/registrations', () async {
      mockApi.getJsonResponse = [
        {'id': 'reg-1', 'employeeId': 'emp-101'}
      ];

      final list = await repository.getRegistrations(employeeId: 'emp-101', branchSlug: 'q1');

      expect(list.length, 1);
      expect(list.first['id'], 'reg-1');
      expect(mockApi.requests.first.path, '/api/shifts/registrations');
      expect(mockApi.requests.first.query?['employeeId'], 'emp-101');
      expect(mockApi.requests.first.query?['branchSlug'], 'q1');
    });
  });

  group('ShiftRepository templates', () {
    test('getTemplates, createTemplate, updateTemplate, deleteTemplate', () async {
      mockApi.getJsonResponse = [
        {'id': 'tpl-1', 'name': 'Ca Sáng'}
      ];
      final templates = await repository.getTemplates();
      expect(templates.length, 1);
      expect(templates.first['name'], 'Ca Sáng');

      mockApi.postJsonResponse = {'id': 'tpl-2', 'name': 'Ca Tối'};
      final created = await repository.createTemplate({'name': 'Ca Tối'});
      expect(created['id'], 'tpl-2');

      await repository.updateTemplate('tpl-2', {'name': 'Ca Đêm'});
      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/shift-templates/tpl-2');

      await repository.deleteTemplate('tpl-2');
      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/shift-templates/tpl-2');
    });
  });
}
