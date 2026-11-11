import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/leave_request/leave_repository.dart';

import 'mock_api_client.dart';

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
          'id': 'req-1',
          'type': 'leave',
          'employeeId': 'emp-101',
          'branchSlug': 'q1',
          'title': 'Xin nghỉ phép cá nhân',
          'content': 'Tôi cần nghỉ 1 ngày có việc gia đình',
          'status': 'pending',
          'createdAt': '2026-11-10T08:00:00Z',
        },
        {
          'id': 'req-2',
          'type': 'advance',
          'employeeId': 'emp-101',
          'title': 'Tạm ứng lương',
          'content': 'Tạm ứng 2.000.000 đ',
          'status': 'approved',
          'reviewedBy': 'manager-1',
          'reviewNote': 'Đã duyệt',
        }
      ];

      final requests = await repository.getRequests(employeeId: 'emp-101');

      expect(requests.length, 2);
      expect(requests[0].id, 'req-1');
      expect(requests[0].type, 'leave');
      expect(requests[0].title, 'Xin nghỉ phép cá nhân');
      expect(requests[0].status, 'pending');

      expect(requests[1].id, 'req-2');
      expect(requests[1].type, 'advance');
      expect(requests[1].reviewedBy, 'manager-1');
      expect(requests[1].reviewNote, 'Đã duyệt');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'GET');
      expect(req.path, '/api/requests');
      expect(req.query?['employeeId'], 'emp-101');
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
        'id': 'req-new',
        'type': 'leave',
        'employeeId': 'emp-101',
        'title': 'Nghỉ ốm',
        'content': 'Bị sốt',
        'status': 'pending',
      };

      final created = await repository.createRequest({
        'type': 'leave',
        'employeeId': 'emp-101',
        'title': 'Nghỉ ốm',
        'content': 'Bị sốt',
      });

      expect(created.id, 'req-new');
      expect(created.title, 'Nghỉ ốm');
      expect(created.status, 'pending');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/requests');
      expect(req.payload?['title'], 'Nghỉ ốm');
    });
  });
}
