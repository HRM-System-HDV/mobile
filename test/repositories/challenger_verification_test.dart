import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/app_notification.dart';
import 'package:mobile/src/core/models/payslip.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'package:mobile/src/features/leave_request/leave_repository.dart';
import 'package:mobile/src/features/salary/salary_repository.dart';
import 'package:mobile/src/features/schedule/shift_repository.dart';
import 'package:mobile/src/features/tasks/task_repository.dart';
import 'package:mobile/src/features/tasks/task_service.dart';
import 'package:mobile/src/features/wifi_config/wifi_config_repository.dart';

import 'mock_api_client.dart';

void main() {
  group('Empirical Challenge 1: MockApiClient Rigor & Stress Test', () {
    late MockApiClient mock;

    setUp(() {
      mock = MockApiClient();
    });

    test('captures complete request metadata across all HTTP verbs and SOAP', () async {
      mock.getJsonResponse = {'msg': 'get_ok'};
      mock.postJsonResponse = {'msg': 'post_ok'};
      mock.putJsonResponse = {'msg': 'put_ok'};
      mock.postSoapResponse = '<soap:Result>soap_ok</soap:Result>';

      final getRes = await mock.getJson('/test/get', query: {'page': '1', 'limit': '20'});
      final postRes = await mock.postJson('/test/post', {'name': 'alice'});
      final putRes = await mock.putJson('/test/put', {'id': 123, 'active': true});
      await mock.delete('/test/delete/99');
      final soapRes = await mock.postSoap('<soap:Action>Check</soap:Action>');

      expect(getRes, {'msg': 'get_ok'});
      expect(postRes, {'msg': 'post_ok'});
      expect(putRes, {'msg': 'put_ok'});
      expect(soapRes, '<soap:Result>soap_ok</soap:Result>');

      expect(mock.requests.length, 5);
      expect(mock.requests[0].method, 'GET');
      expect(mock.requests[0].path, '/test/get');
      expect(mock.requests[0].query, {'page': '1', 'limit': '20'});

      expect(mock.requests[1].method, 'POST');
      expect(mock.requests[1].path, '/test/post');
      expect(mock.requests[1].payload, {'name': 'alice'});

      expect(mock.requests[2].method, 'PUT');
      expect(mock.requests[2].path, '/test/put');
      expect(mock.requests[2].payload, {'id': 123, 'active': true});

      expect(mock.requests[3].method, 'DELETE');
      expect(mock.requests[3].path, '/test/delete/99');

      expect(mock.requests[4].method, 'SOAP');
      expect(mock.requests[4].path, '/soap/payroll');
      expect(mock.requests[4].payload, {'xml': '<soap:Action>Check</soap:Action>'});
    });

    test('reset clears request history and all handlers/responses', () async {
      mock.getJsonResponse = 'data';
      mock.getJsonHandler = (_, __) => 'from_handler';
      mock.deleteHandler = (_) {};
      await mock.getJson('/path');
      await mock.delete('/path');

      expect(mock.requests.length, 2);

      mock.reset();

      expect(mock.requests, isEmpty);
      expect(mock.getJsonResponse, isNull);
      expect(mock.getJsonHandler, isNull);
      expect(mock.deleteHandler, isNull);
      expect(mock.postJsonResponse, isNull);
      expect(mock.putJsonResponse, isNull);
      expect(mock.postSoapResponse, isNull);

      // Calling after reset returns null/default
      final res = await mock.getJson('/path_new');
      expect(res, isNull);
      expect(mock.requests.length, 1);
    });

    test('handler precedence: dynamic handlers override static responses', () async {
      mock.getJsonResponse = 'static_get';
      mock.getJsonHandler = (path, query) => 'dynamic_get:$path:${query?['q']}';

      mock.postJsonResponse = 'static_post';
      mock.postJsonHandler = (path, payload) => 'dynamic_post:${payload['key']}';

      final getResult = await mock.getJson('/items', query: {'q': 'flutter'});
      final postResult = await mock.postJson('/items', {'key': 'val'});

      expect(getResult, 'dynamic_get:/items:flutter');
      expect(postResult, 'dynamic_post:val');
    });

    test('error propagation: ApiException and other exceptions bubble accurately', () async {
      mock.getJsonHandler = (path, query) {
        throw const ApiException('RATE_LIMITED', 'Quá số lượng yêu cầu', 429);
      };

      expect(
        () => mock.getJson('/throttle'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'RATE_LIMITED')
            .having((e) => e.status, 'status', 429)),
      );
    });
  });

  group('Empirical Challenge 2: All 6 Repositories Stress Harness', () {
    late MockApiClient mock;

    setUp(() {
      mock = MockApiClient();
    });

    test('ShiftRepository: handles malformed lists, null query parameters, and date normalization', () async {
      final repo = ShiftRepository(api: mock);

      // Null response returns empty list safely
      mock.getJsonResponse = null;
      var shifts = await repo.getShifts();
      expect(shifts, isEmpty);

      // Response with mixed types (non-maps) is filtered cleanly
      mock.getJsonResponse = [
        'not_a_map',
        42,
        {'id': 'shift-ok', 'workDate': '2026-11-20', 'templateId': 'tpl-morning', 'scheduledStart': '08:00', 'scheduledEnd': '12:00'}
      ];
      // work-service từ chối DD/MM/YYYY: repository phải chuẩn hoá về ISO.
      shifts = await repo.getShifts(workDate: '20/11/2026');
      expect(shifts.length, 1);
      expect(shifts.first.id, 'shift-ok');
      expect(shifts.first.workDate, '2026-11-20');
      expect(shifts.first.templateId, 'tpl-morning');
      expect(mock.requests.last.query?['workDate'], '2026-11-20');
      expect(mock.requests.last.query?.containsKey('date'), isFalse);
    });

    test('AttendanceRepository: checkIn payload fidelity and error handling', () async {
      final repo = AttendanceRepository(api: mock);

      // Full checkin
      mock.postJsonResponse = {
        'id': 'att-100',
        'employeeId': 'emp-1',
        'shiftId': 's-1',
        'workDate': '2026-11-20',
        'checkIn': '2026-11-20T07:55:00.000Z',
        'status': 'present',
      };

      final att = await repo.checkIn(
        employeeId: 'emp-1',
        shiftId: 's-1',
        wifiSsid: 'Corp_WiFi',
        wifiBssid: 'AA:BB:CC:11:22:33',
      );

      expect(att.id, 'att-100');
      expect(att.workDate, '2026-11-20');
      // work-service: fields(payload, ["employeeId", "shiftId", "wifi"]) — đúng 3 khóa.
      expect(mock.requests.first.payload!.keys.toSet(),
          {'employeeId', 'shiftId', 'wifi'});
      expect(mock.requests.first.payload?['wifi'],
          {'ssid': 'Corp_WiFi', 'bssid': 'AA:BB:CC:11:22:33'});

      // Minimal checkin: wifi object rỗng, không có khóa rời
      mock.reset();
      mock.postJsonResponse = {'id': 'att-101', 'employeeId': 'emp-1', 'shiftId': 's-2', 'workDate': '2026-11-20'};
      await repo.checkIn(employeeId: 'emp-1', shiftId: 's-2');
      expect(mock.requests.first.payload?.containsKey('wifiBssid'), false);
      expect(mock.requests.first.payload?.containsKey('wifiSsid'), false);
      expect(mock.requests.first.payload?['wifi'], isEmpty);
      expect(mock.requests.first.payload?.containsKey('checkinTime'), isFalse);

      // getConfig nổ lỗi khi server lỗi: lỗi phải được báo ra chứ không lặng
      // lẽ trả cấu hình rỗng.
      mock.getJsonHandler = (_, __) => throw const ApiException('CRASH', 'Server down', 500);
      await expectLater(repo.getConfig(), throwsA(isA<ApiException>()));
    });

    test('LeaveRepository: handles null query and deserializes LeaveRequestModel cleanly', () async {
      final repo = LeaveRepository(api: mock);

      mock.getJsonResponse = [
        {'id': 'req-1', 'type': 'leave', 'employeeId': 'emp-1', 'title': 'Nghỉ Tết', 'content': 'Nghỉ', 'status': 'pending'}
      ];

      final reqs = await repo.getRequests();
      expect(reqs.length, 1);
      expect(reqs.first.id, 'req-1');
      expect(mock.requests.first.query?.containsKey('employeeId'), false);
    });

    test('SalaryRepository: unwraps both raw lists and items-envelope responses', () async {
      final repo = SalaryRepository(api: mock);

      // Envelope { items: [...] }
      mock.getJsonResponse = {
        'items': [
          {'id': 'ps-1', 'employeeId': 'emp-1', 'month': '11-2026', 'baseSalary': 10000000, 'netSalary': 10000000, 'totalPenalty': 0, 'status': 'draft'}
        ]
      };
      var payslips = await repo.getPayslips();
      expect(payslips.length, 1);
      expect(payslips.first.id, 'ps-1');

      // Direct list [...]
      mock.getJsonResponse = [
        {'id': 'ps-2', 'employeeId': 'emp-2', 'month': '11-2026', 'baseSalary': 20000000, 'bonus': 5000000, 'netSalary': 25000000, 'totalPenalty': 0, 'status': 'paid'}
      ];
      payslips = await repo.getPayslips();
      expect(payslips.length, 1);
      expect(payslips.first.bonus, 5000000.0);
    });

    test('TaskRepository: translates complex status/priority enums and sets completion timestamps', () async {
      final repo = TaskRepository(api: mock);

      mock.getJsonResponse = [
        {'id': 't-1', 'title': 'Task 1', 'status': 'đã xong', 'priority': 'khẩn cấp'},
        {'id': 't-2', 'title': 'Task 2', 'status': 'đang làm', 'priority': 'cao'},
        {'id': 't-3', 'title': 'Task 3', 'status': 'pending', 'priority': 'normal'},
      ];

      final tasks = await repo.getTasks();
      expect(tasks[0].status, TaskStatus.completed);
      expect(tasks[0].priority, TaskPriority.urgent);

      expect(tasks[1].status, TaskStatus.inProgress);
      expect(tasks[1].priority, TaskPriority.high);

      expect(tasks[2].status, TaskStatus.pending);
      expect(tasks[2].priority, TaskPriority.normal);

      // updateTaskStatus: backend tự set completedAt/photoSubmittedAt/
      // photoSubmittedBy, client chỉ được gửi status + proofPhotoUrl (TASK_FIELDS).
      mock.reset();
      mock.putJsonResponse = {'ok': true};
      await repo.updateTaskStatus('t-1', 'completed', proofUrl: 'http://cdn/photo.jpg');
      final payload = mock.requests.first.payload!;
      expect(payload.keys.toSet(), {'status', 'proofPhotoUrl'});
      expect(payload['status'], 'done',
          reason: 'work-service lưu "done", không phải "completed"');
      expect(payload['proofPhotoUrl'], 'http://cdn/photo.jpg');
      expect(payload.containsKey('completedAt'), isFalse,
          reason: 'completedAt do server đặt, gửi lên là key thừa -> 400');
      expect(payload.containsKey('photoSubmittedAt'), isFalse);
      expect(payload.containsKey('photoSubmittedBy'), isFalse);
      expect(mock.requests.first.path, '/api/tasks/t-1');

      // Đang làm việc thì gửi "in_progress" (không có ảnh minh chứng).
      mock.reset();
      await repo.updateTaskStatus('t-2', 'inProgress');
      expect(mock.requests.first.payload, {'status': 'in_progress'});
    });

    test('WifiConfigRepository: lọc theo branchId UUID và ghi đúng 4 khóa CRUD', () async {
      final repo = WifiConfigRepository(api: mock);

      mock.getJsonResponse = [];
      // Không còn endpoint /scan và không còn bộ lọc tên chi nhánh: chỉ có
      // GET /api/wifi-configs?branchId=<UUID>.
      await repo.getWifiConfigs(branchId: '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61');
      expect(mock.requests.length, 1);
      expect(mock.requests.first.method, 'GET');
      expect(mock.requests.first.path, '/api/wifi-configs');
      expect(mock.requests.first.query, {
        'branchId': '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61'
      });
      expect(mock.requests.first.query?.containsKey('branch'), isFalse);

      mock.reset();
      mock.postJsonResponse = {
        'id': 'w-1',
        'ssid': 'Test',
        'bssid': '00:11:22:33:44:55',
        'branchId': '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61',
        'status': 'hoạt động',
      };
      final created = await repo.createWifiConfig(
        ssid: 'Test',
        bssid: '00:11:22:33:44:55',
        branchId: '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61',
      );
      expect(created.id, 'w-1');
      expect(created.branchId, '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61');
      expect(mock.requests.first.method, 'POST');
      expect(mock.requests.first.path, '/api/wifi-configs');
      // contentFields.wifiConfig = ssid, bssid, branchId, status — thêm khóa là 400.
      expect(mock.requests.first.payload!.keys.toSet(),
          {'ssid', 'bssid', 'branchId', 'status'});
      expect(mock.requests.first.payload, {
        'ssid': 'Test',
        'bssid': '00:11:22:33:44:55',
        'branchId': '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61',
        'status': 'hoạt động',
      });
    });
  });

  group('Empirical Challenge 3: PayslipModel.fromJson Bonus Field Resilience', () {
    test('bonus is MISSING from JSON -> defaults cleanly to 0.0', () {
      final json = <String, dynamic>{
        'id': 'ps-1',
        'employeeId': 'emp-1',
        'month': '11-2026',
        'baseSalary': 15000000,
        'totalPenalty': 200000,
        'netSalary': 14800000,
        'status': 'paid',
      };
      final model = PayslipModel.fromJson(json);
      expect(model.bonus, 0.0);
      expect(model.bonus, isA<double>());
    });

    test('bonus is NULL in JSON -> defaults cleanly to 0.0', () {
      final json = <String, dynamic>{
        'id': 'ps-2',
        'employeeId': 'emp-1',
        'month': '11-2026',
        'baseSalary': 15000000,
        'bonus': null,
        'totalPenalty': 0,
        'netSalary': 15000000,
        'status': 'paid',
      };
      final model = PayslipModel.fromJson(json);
      expect(model.bonus, 0.0);
      expect(model.bonus, isA<double>());
    });

    test('bonus is INT in JSON -> safely converted to double', () {
      final json = <String, dynamic>{
        'id': 'ps-3',
        'employeeId': 'emp-1',
        'month': '11-2026',
        'baseSalary': 10000000,
        'bonus': 3500000, // int
        'totalPenalty': 0,
        'netSalary': 13500000,
        'status': 'paid',
      };
      final model = PayslipModel.fromJson(json);
      expect(model.bonus, 3500000.0);
      expect(model.bonus, isA<double>());
    });

    test('bonus is DOUBLE in JSON -> preserved as double', () {
      final json = <String, dynamic>{
        'id': 'ps-4',
        'employeeId': 'emp-1',
        'month': '11-2026',
        'baseSalary': 10000000,
        'bonus': 2500000.75, // double
        'totalPenalty': 0,
        'netSalary': 12500000.75,
        'status': 'paid',
      };
      final model = PayslipModel.fromJson(json);
      expect(model.bonus, 2500000.75);
      expect(model.bonus, isA<double>());
    });

    test('bonus with zero int/double and negative values', () {
      final modelZeroInt = PayslipModel.fromJson({'bonus': 0});
      expect(modelZeroInt.bonus, 0.0);

      final modelZeroDouble = PayslipModel.fromJson({'bonus': 0.0});
      expect(modelZeroDouble.bonus, 0.0);

      final modelNeg = PayslipModel.fromJson({'bonus': -500000});
      expect(modelNeg.bonus, -500000.0);
    });

    test('toJson serializes bonus and round-trips correctly', () {
      const original = PayslipModel(
        id: 'ps-99',
        employeeId: 'emp-99',
        month: '11-2026',
        baseSalary: 12000000.0,
        bonus: 1500000.0,
        totalPenalty: 100000.0,
        netSalary: 13400000.0,
        status: 'approved',
      );

      final map = original.toJson();
      expect(map['bonus'], 1500000.0);

      final reconstructed = PayslipModel.fromJson(map);
      expect(reconstructed.id, original.id);
      expect(reconstructed.bonus, original.bonus);
      expect(reconstructed.netSalary, original.netSalary);
    });
  });

  group('Empirical Challenge 4: AppNotificationModel.fromJson Metadata Resilience', () {
    test('metadata is NULL -> parsed as null without error', () {
      final json = <String, dynamic>{
        'id': 'notif-1',
        'title': 'Thông báo chung',
        'body': 'Nội dung',
        'isRead': false,
        'metadata': null,
      };
      final model = AppNotificationModel.fromJson(json);
      expect(model.metadata, isNull);
    });

    test('metadata is EMPTY MAP -> parsed as empty Map<String, dynamic>', () {
      final json = <String, dynamic>{
        'id': 'notif-2',
        'title': 'Thông báo',
        'body': 'Nội dung',
        'isRead': true,
        'metadata': <String, dynamic>{},
      };
      final model = AppNotificationModel.fromJson(json);
      expect(model.metadata, isNotNull);
      expect(model.metadata, isEmpty);
      expect(model.metadata, isA<Map<String, dynamic>>());
    });

    test('metadata is POPULATED MAP -> preserves all keys and types', () {
      final json = <String, dynamic>{
        'id': 'notif-3',
        'title': 'Đổi ca',
        'body': 'Yêu cầu đổi ca từ Nhân viên B',
        'isRead': false,
        'metadata': {
          'shiftId': 's-123',
          'requestType': 'swap',
          'extraInfo': {'subKey': 42},
          'tags': ['urgent', 'morning'],
        },
      };
      final model = AppNotificationModel.fromJson(json);
      expect(model.metadata, isNotNull);
      expect(model.metadata?['shiftId'], 's-123');
      expect(model.metadata?['requestType'], 'swap');
      expect(model.metadata?['extraInfo']['subKey'], 42);
      expect(model.metadata?['tags'], ['urgent', 'morning']);
    });

    test('metadata is NON-MAP (string, list, int, bool) -> safely treated as null without throwing', () {
      // String
      final modelString = AppNotificationModel.fromJson({
        'id': 'n-str',
        'title': 'Test',
        'body': 'Body',
        'metadata': '{"serialized": "string"}',
      });
      expect(modelString.metadata, isNull);

      // List
      final modelList = AppNotificationModel.fromJson({
        'id': 'n-list',
        'title': 'Test',
        'body': 'Body',
        'metadata': ['item1', 'item2'],
      });
      expect(modelList.metadata, isNull);

      // Int
      final modelInt = AppNotificationModel.fromJson({
        'id': 'n-int',
        'title': 'Test',
        'body': 'Body',
        'metadata': 12345,
      });
      expect(modelInt.metadata, isNull);

      // Bool
      final modelBool = AppNotificationModel.fromJson({
        'id': 'n-bool',
        'title': 'Test',
        'body': 'Body',
        'metadata': true,
      });
      expect(modelBool.metadata, isNull);
    });

    test('chi tiết ca lấy từ metadata; branchId là cột, không còn branchSlug', () {
      const branchId = '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61';
      final json = <String, dynamic>{
        'id': 'n-meta',
        'title': 'Yêu cầu làm thay',
        'body': 'Cần người làm thay',
        'branchId': branchId,
        'requestType': 'cover',
        'requestId': 'req-9',
        'senderName': 'Trần Văn B',
        'metadata': {
          'shiftName': 'Ca Tối 18h-22h',
          'shiftDate': '20/11/2026',
          'shiftTime': '18:00 - 22:00',
          'shiftHours': '4.0',
          'senderRole': 'Pha chế',
          'senderPhone': '0901234567',
        },
      };
      final model = AppNotificationModel.fromJson(json);
      expect(model.branchId, branchId);
      expect(model.requestType, 'cover');
      expect(model.requestId, 'req-9');
      expect(model.shiftName, 'Ca Tối 18h-22h');
      expect(model.shiftDate, '20/11/2026');
      expect(model.shiftTime, '18:00 - 22:00');
      expect(model.shiftHours, '4.0');
      expect(model.senderName, 'Trần Văn B');
      expect(model.senderRole, 'Pha chế');
      expect(model.senderPhone, '0901234567');
    });

    test('metadata thiếu/rỗng thì các trường chi tiết là null, không suy từ top-level', () {
      // integration-service chỉ pick targetEmployeeId, branchId, title, body,
      // metadata, requestId, requestType — mọi alias kiểu cũ ('shift', 'date',
      // 'role', 'phone'...) chưa bao giờ là cột nên không được đọc nữa.
      final legacy = AppNotificationModel.fromJson(<String, dynamic>{
        'id': 'n-legacy',
        'title': 'Yêu cầu làm thay',
        'body': 'Cần người làm thay',
        'branch': 'q1',
        'request_type': 'cover',
        'shift': 'Ca Tối 18h-22h',
        'date': '20/11/2026',
        'time': '18:00 - 22:00',
        'hours': '4.0',
        'sender': 'Trần Văn B',
        'role': 'Pha chế',
        'phone': '0901234567',
      });
      expect(legacy.branchId, isNull);
      expect(legacy.requestType, isNull);
      expect(legacy.shiftName, isNull);
      expect(legacy.shiftDate, isNull);
      expect(legacy.shiftTime, isNull);
      expect(legacy.shiftHours, isNull);
      expect(legacy.senderName, isNull);
      expect(legacy.senderRole, isNull);
      expect(legacy.senderPhone, isNull);

      // Giá trị rỗng trong metadata được coi là "không có" chứ không phải ''.
      final blank = AppNotificationModel.fromJson({
        'id': 'n-blank',
        'title': 'T',
        'body': 'B',
        'metadata': {'shiftName': '   ', 'senderPhone': null},
      });
      expect(blank.shiftName, isNull);
      expect(blank.senderPhone, isNull);
    });

    test('isRead parsing: strict boolean check', () {
      expect(AppNotificationModel.fromJson({'id': '1', 'isRead': true}).isRead, isTrue);
      expect(AppNotificationModel.fromJson({'id': '2', 'isRead': false}).isRead, isFalse);
      expect(AppNotificationModel.fromJson({'id': '3', 'isRead': null}).isRead, isFalse);
      expect(AppNotificationModel.fromJson({'id': '4', 'isRead': 'true'}).isRead, isFalse);
      expect(AppNotificationModel.fromJson({'id': '5', 'isRead': 1}).isRead, isFalse);
    });

    test('toJson chỉ ghi các cột thật và giữ nguyên metadata cho vòng sau', () {
      const original = AppNotificationModel(
        id: 'notif-rt',
        targetEmployeeId: 'emp-101',
        branchId: '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61',
        title: 'Title RT',
        body: 'Body RT',
        isRead: true,
        metadata: {
          'shiftName': 'Ca Sáng',
          'shiftDate': '21/11/2026',
          'senderRole': 'Phục vụ',
          'senderPhone': '0912345678',
        },
        requestType: 'swap',
        senderName: 'Lê Văn C',
        createdAt: '2026-11-20T10:00:00Z',
      );

      final map = original.toJson();
      expect(map['id'], 'notif-rt');
      expect(map['branchId'], '2f7c1f3a-9c1e-4f6a-9a3b-1d2c3f4a5b61');
      expect(map['metadata'], {
        'shiftName': 'Ca Sáng',
        'shiftDate': '21/11/2026',
        'senderRole': 'Phục vụ',
        'senderPhone': '0912345678',
      });
      expect(map['requestType'], 'swap');
      // Trường hiển thị không được thành khóa top-level (bảng notifications không có).
      expect(map.containsKey('shiftName'), isFalse);
      expect(map.containsKey('senderPhone'), isFalse);

      final reconstructed = AppNotificationModel.fromJson(map);
      expect(reconstructed.id, original.id);
      expect(reconstructed.branchId, original.branchId);
      expect(reconstructed.isRead, isTrue);
      expect(reconstructed.requestType, original.requestType);
      expect(reconstructed.senderName, original.senderName);
      expect(reconstructed.shiftName, 'Ca Sáng');
      expect(reconstructed.shiftDate, '21/11/2026');
      expect(reconstructed.senderRole, 'Phục vụ');
      expect(reconstructed.senderPhone, '0912345678');
    });
  });
}
