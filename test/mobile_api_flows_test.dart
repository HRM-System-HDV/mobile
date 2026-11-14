import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/features/attendance/adjustment.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'package:mobile/src/features/schedule/shift_detail.dart';
import 'package:mobile/src/features/home/home.dart';
import 'package:mobile/src/features/leave_request/leave_repository.dart';
import 'package:mobile/src/features/schedule/shift_form.dart';
import 'package:mobile/src/features/schedule/schedule_service.dart';
import 'package:mobile/src/features/schedule/shift_repository.dart';
import 'repositories/mock_api_client.dart';

const user = UserModel(
    id: 'account-id',
    employeeId: 'employee-id',
    name: 'Test',
    email: 'test@test.local',
    role: 'manager');
const shift = ShiftDetail(
    id: 'source-shift',
    shiftName: 'Ca sáng',
    startTime: '07:00',
    endTime: '15:00',
    hours: 8,
    branch: 'HN',
    role: 'Nhân viên',
    status: 'upcoming');

Future<void> host(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final notifier = ValueNotifier<UserModel?>(user);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
      MaterialApp(home: UserScope(notifier: notifier, child: screen)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Nghỉ ca gửi ngày nghỉ và employeeId, không gửi sourceShiftId',
      (tester) async {
    final api = MockApiClient()..postJsonResponse = {'id': 'request'};
    await host(
        tester,
        ShiftActionFormScreen(
            shift: shift,
            date: '01/01/2099',
            dayOfWeek: 'T2',
            actionType: ShiftActionType.leave,
            leaveRepository: LeaveRepository(api: api)));
    await tester.enterText(find.byType(TextFormField), 'Có việc gia đình');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    final body = api.requests.single.payload!;
    expect(body['employeeId'], 'employee-id');
    expect(body['leaveStartDate'], '2099-01-01');
    expect(body['leaveEndDate'], '2099-01-01');
    expect(body.containsKey('sourceShiftId'), false);
    expect(body.containsKey('notification'), false);
  });

  testWidgets('Nhờ làm thay lấy danh bạ theo ca và để backend gửi thông báo',
      (tester) async {
    final api = MockApiClient()..postJsonResponse = {'id': 'request'};
    api.getJsonHandler = (path, query) => path == '/api/requests/shift-options'
        ? {
            'employees': [
              {'id': 'target-id', 'name': 'Đồng nghiệp'}
            ],
            'shifts': []
          }
        : [];
    await host(
        tester,
        ShiftActionFormScreen(
            shift: shift,
            date: '01/01/2099',
            dayOfWeek: 'T2',
            actionType: ShiftActionType.cover,
            leaveRepository: LeaveRepository(api: api),
            shiftRepository: ShiftRepository(api: api)));
    expect(api.requests.first.query, {'sourceShiftId': 'source-shift'});
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng nghiệp').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    final body = api.requests.last.payload!;
    expect(body['employeeId'], 'employee-id');
    expect(body['sourceShiftId'], 'source-shift');
    expect(body['targetEmployeeId'], 'target-id');
    expect(body.containsKey('notification'), false);
  });

  testWidgets(
      'Chi tiết ca tải công theo employeeId và tính giờ qua đêm từ timestamp',
      (tester) async {
    final api = MockApiClient()
      ..getJsonResponse = [
        {
          'id': 'att',
          'shiftId': 'source-shift',
          'employeeId': 'employee-id',
          'workDate': '2020-01-01',
          'checkIn': DateTime(2020, 1, 1, 22).toUtc().toIso8601String(),
          'checkOut': DateTime(2020, 1, 2, 6).toUtc().toIso8601String(),
          'status': 'present',
        }
      ];
    await host(
        tester,
        ShiftDetailScreen(
            shift: shift,
            date: '01/01/2020',
            dayOfWeek: 'T2',
            attendanceRepository: AttendanceRepository(api: api)));
    expect(api.requests.single.query, {'employeeId': 'employee-id'});
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('8.0 giờ'), findsOneWidget);
  });

  testWidgets('Trang chủ khôi phục ca đang làm từ API khi mở ứng dụng',
      (tester) async {
    final api = MockApiClient();
    api.getJsonHandler = (path, query) => path == '/api/shifts'
        ? [
            {
              'id': 'active-shift',
              'employeeId': 'employee-id',
              'workDate': '2020-01-01',
              'templateId': 'template',
              'scheduledStart': '22:00',
              'scheduledEnd': '06:00',
              'attendanceState': 'working',
              'canCheckout': true,
              'attendance': {
                'id': 'att',
                'shiftId': 'active-shift',
                'checkIn': DateTime(2020, 1, 1, 22).toUtc().toIso8601String()
              },
            }
          ]
        : [
            {'id': 'template', 'name': 'Ca đêm'}
          ];
    await host(
        tester,
        HomeScreen(
            currentUser: user, shiftRepository: ShiftRepository(api: api)));
    expect(find.text('Chấm công ra ca'), findsOneWidget);
    expect(api.requests.first.query, {'employeeId': 'employee-id'});
  });

  for (final inTime in ['22:00', '00:10']) {
    testWidgets(
        'Bổ sung công qua đêm với giờ vào $inTime gửi timestamp có múi giờ',
        (tester) async {
      final api = MockApiClient()..postJsonResponse = {'id': 'request'};
      api.getJsonHandler = (path, query) => path == '/api/shifts'
          ? [
              {
                'id': 'real-shift',
                'employeeId': 'employee-id',
                'workDate': '2020-01-01',
                'templateId': 'template',
                'scheduledStart': '22:00',
                'scheduledEnd': '06:00',
              }
            ]
          : [];
      await host(
          tester,
          AttendanceAdjustmentScreen(
              leaveRepository: LeaveRepository(api: api),
              shiftRepository: ShiftRepository(api: api)));
      expect(api.requests.every((r) => r.query?['employeeId'] == 'employee-id'),
          true);
      await tester.tap(find.text('Tạo yêu cầu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), inTime);
      await tester.enterText(find.byType(TextField).at(1), '06:00');
      await tester.enterText(find.byType(TextField).at(2), 'Quên chấm công');
      await tester.tap(find.text('Gửi yêu cầu bổ sung'));
      await tester.pumpAndSettle();
      final body = api.requests.firstWhere((r) => r.method == 'POST').payload!;
      expect(body['employeeId'], 'employee-id');
      expect(body['sourceShiftId'], 'real-shift');
      expect(
          DateTime.parse(body['requestedCheckIn']).toLocal(),
          inTime == '22:00'
              ? DateTime(2020, 1, 1, 22)
              : DateTime(2020, 1, 2, 0, 10));
      expect(DateTime.parse(body['requestedCheckOut']).toLocal(),
          DateTime(2020, 1, 2, 6));
    });
  }
}
