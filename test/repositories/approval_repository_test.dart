import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/approvals/approval_repository.dart';
import 'package:mobile/src/features/approvals/approvals.dart';

import 'mock_api_client.dart';

const _employeeUuid = '3d4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7080';
const _branchUuid = '1b2b3b4b-5c6d-7e8f-9a0b-1c2d3e4f5060';
const _requestUuid = '4e5f6a7b-8c9d-0e1f-2a3b-4c5d6e7f8090';

Map<String, dynamic> _swapRow(String mode) => {
      'id': _requestUuid,
      'type': 'shift_swap',
      'employeeId': _employeeUuid,
      'branchId': _branchUuid,
      'title': 'Đổi ca: Sáng',
      'content': 'Việc gia đình',
      'status': 'pending',
      'shiftSwapMode': mode,
      'createdAt': '2026-11-14T02:00:00.000Z',
    };

void main() {
  late MockApiClient mockApi;
  late ApprovalRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = ApprovalRepository(api: mockApi);
  });

  group('ApprovalRepository routes', () {
    test('getPending reads pending requests and keeps shiftSwapMode of each row', () async {
      mockApi.getJsonResponse = [_swapRow('mutual_acceptance')];

      final rows = await repository.getPending();

      expect(rows.single.shiftSwapMode, 'mutual_acceptance');
      expect(mockApi.requests.single.method, 'GET');
      expect(mockApi.requests.single.path, '/api/requests');
      expect(mockApi.requests.single.query?['status'], 'pending');
    });

    test('get reads one request so the peer screen uses the mode of that request', () async {
      mockApi.getJsonResponse = _swapRow('manager_approval');

      final row = await repository.get(_requestUuid);

      expect(row.shiftSwapMode, 'manager_approval');
      expect(mockApi.requests.single.method, 'GET');
      expect(mockApi.requests.single.path, '/api/requests/$_requestUuid');
    });

    test('manager uses approve/reject', () async {
      await repository.approve(_requestUuid, note: 'OK');
      await repository.reject(_requestUuid);

      expect(mockApi.requests[0].method, 'PUT');
      expect(mockApi.requests[0].path, '/api/requests/$_requestUuid/approve');
      expect(mockApi.requests[0].payload?['reviewNote'], 'OK');
      expect(mockApi.requests[1].path, '/api/requests/$_requestUuid/reject');
    });

    test('target employee uses accept/decline, never approve', () async {
      await repository.respond(_requestUuid, accept: true);
      await repository.respond(_requestUuid, accept: false);

      expect(mockApi.requests[0].method, 'PUT');
      expect(mockApi.requests[0].path, '/api/requests/$_requestUuid/accept');
      expect(mockApi.requests[1].path, '/api/requests/$_requestUuid/decline');
    });
  });

  group('ShiftRequest.peerMustRespond', () {
    ShiftRequest build({
      ShiftRequestType type = ShiftRequestType.swap,
      String? mode,
    }) =>
        ShiftRequest(
          id: _requestUuid,
          staffName: 'Nguyễn Văn A',
          staffRole: 'Nhân viên',
          staffAvatar: 'NA',
          type: type,
          currentShift: 'Sáng 06:00-14:00',
          reason: 'Việc gia đình',
          submittedAt: '2026-11-14T02:00:00.000Z',
          shiftSwapMode: mode,
        );

    test('is true only for a swap request captured in mutual_acceptance', () {
      expect(build(mode: 'mutual_acceptance').peerMustRespond, isTrue);
      expect(build(mode: 'manager_approval').peerMustRespond, isFalse);
      expect(build(mode: null).peerMustRespond, isFalse);
    });

    test('is false for the other request types even if a mode is present', () {
      expect(build(type: ShiftRequestType.leave, mode: 'mutual_acceptance').peerMustRespond, isFalse);
      expect(build(type: ShiftRequestType.advance, mode: 'mutual_acceptance').peerMustRespond, isFalse);
      expect(build(type: ShiftRequestType.adjustment, mode: 'mutual_acceptance').peerMustRespond, isFalse);
    });
  });
}
