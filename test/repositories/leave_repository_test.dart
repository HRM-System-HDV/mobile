import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/leave_request/leave_repository.dart';

import 'mock_api_client.dart';

const _employeeUuid = '3d4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7080';
const _branchUuid = '1b2b3b4b-5c6d-7e8f-9a0b-1c2d3e4f5060';
const _requestUuid = '4e5f6a7b-8c9d-0e1f-2a3b-4c5d6e7f8090';
const _managerUuid = '5f6a7b8c-9d0e-1f2a-3b4c-5d6e7f809100';

void main() {
  late MockApiClient mockApi;
  late LeaveRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = LeaveRepository(api: mockApi);
  });

  group('LeaveRepository.getRequests', () {
    test('fetches and parses leave requests with employeeId query', () async {
      mockApi.getJsonResponse = [
        {
          'id': _requestUuid,
          'type': 'leave',
          'employeeId': _employeeUuid,
          'branchId': _branchUuid,
          'title': 'Xin nghỉ phép cá nhân',
          'content': 'Tôi cần nghỉ 1 ngày có việc gia đình',
          'leaveStartDate': '2026-11-12',
          'leaveEndDate': '2026-11-13',
          'status': 'pending',
          'createdAt': '2026-11-10T08:00:00.000Z',
        },
        {
          'id': '6a7b8c9d-0e1f-2a3b-4c5d-6e7f80910110',
          'type': 'advance',
          'employeeId': _employeeUuid,
          'branchId': _branchUuid,
          'title': 'Tạm ứng lương',
          'content': 'Tạm ứng 2000000 đ',
          'advanceAmount': '2000000',
          'status': 'approved',
          'reviewedBy': _managerUuid,
          'reviewNote': 'Đã duyệt',
        }
      ];

      final requests = await repository.getRequests(employeeId: _employeeUuid);

      expect(requests.length, 2);
      expect(requests[0].id, _requestUuid);
      expect(requests[0].type, 'leave');
      expect(requests[0].branchId, _branchUuid);
      expect(requests[0].title, 'Xin nghỉ phép cá nhân');
      expect(requests[0].leaveStartDate, '2026-11-12');
      expect(requests[0].leaveEndDate, '2026-11-13');
      expect(requests[0].status, 'pending');

      expect(requests[1].type, 'advance');
      expect(requests[1].reviewedBy, _managerUuid);
      expect(requests[1].reviewNote, 'Đã duyệt');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'GET');
      expect(req.path, '/api/requests');
      expect(req.query?['employeeId'], _employeeUuid);
    });

    test('handles empty response gracefully', () async {
      mockApi.getJsonResponse = [];
      final requests = await repository.getRequests();
      expect(requests, isEmpty);
    });

    test('propagates ApiException when getRequests fails', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('UNAUTHORIZED', 'Hết phiên đăng nhập', 401);
      };

      expect(
        () => repository.getRequests(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
      );
    });
  });

  group('LeaveRepository.createRequest', () {
    test('posts payload to /api/requests and returns created model', () async {
      mockApi.postJsonResponse = {
        'id': _requestUuid,
        'type': 'leave',
        'employeeId': _employeeUuid,
        'branchId': _branchUuid,
        'title': 'Nghỉ ốm',
        'content': 'Bị sốt',
        'leaveStartDate': '2026-11-20',
        'leaveEndDate': '2026-11-21',
        'status': 'pending',
      };

      final created = await repository.createRequest({
        'type': 'leave',
        'employeeId': _employeeUuid,
        'title': 'Nghỉ ốm',
        'content': 'Bị sốt',
        'leaveStartDate': '2026-11-20',
        'leaveEndDate': '2026-11-21',
      });

      expect(created.id, _requestUuid);
      expect(created.title, 'Nghỉ ốm');
      expect(created.branchId, _branchUuid);
      expect(created.leaveStartDate, '2026-11-20');
      expect(created.leaveEndDate, '2026-11-21');
      expect(created.status, 'pending');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/requests');
      expect(req.payload?['title'], 'Nghỉ ốm');
      expect(req.payload?.containsKey('branchSlug'), isFalse);
      expect(req.payload?.containsKey('notification'), isFalse);
    });
  });
}
