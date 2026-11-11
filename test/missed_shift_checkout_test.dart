import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'package:mobile/src/features/schedule/general.dart';
import 'package:mobile/src/features/schedule/staff_detail.dart';

import 'repositories/mock_api_client.dart';

/// Một dòng ca đã check-in nhưng quá hạn chốt ra: backend chiếu status 'missed'
/// và giữ checkOut = null nên ca không được tính công.
StaffInShift _missedStaff() => const StaffInShift(
      id: 'emp-1',
      name: 'Nguyễn Văn A',
      role: 'Nhân viên',
      checkInStatus: 'checked_in',
      checkInTime: '07:00',
      checkOutTime: '',
      phone: '0900000000',
      shiftId: 'shift-row-1',
      attendanceStatus: 'missed',
    );

GeneralShiftModel _shift(StaffInShift staff) => GeneralShiftModel(
      id: 'tpl-morning',
      shiftName: 'Ca Sáng',
      startTime: '07:00',
      endTime: '15:00',
      status: 'in_progress',
      staffList: [staff],
    );

GeneralDayModel _day(GeneralShiftModel shift) =>
    GeneralDayModel(dayOfWeek: 'T2', date: '01/01/2020', shifts: [shift]);

UserModel _user({required String role, String? name}) => UserModel(
      id: role == 'staff' ? 'emp-1' : 'u-$role',
      name: name ?? (role == 'staff' ? 'Nguyễn Văn A' : 'Người quản lý'),
      email: '$role@test.local',
      role: role,
      roleTitle: role,
    );

/// Bọc màn chi tiết trong UserScope để [UserScope.canManage] đọc đúng vai trò.
Widget _host(Widget child, UserModel user) {
  final notifier = ValueNotifier<UserModel?>(user);
  addTearDown(notifier.dispose);
  return MaterialApp(
    home: UserScope(notifier: notifier, child: child),
  );
}

void main() {
  testWidgets('Admin thấy đường chốt ra cho ca bị bỏ qua (missed)', (tester) async {
    final staff = _missedStaff();
    final shift = _shift(staff);
    await tester.pumpWidget(
      _host(
        StaffGeneralShiftDetailScreen(staff: staff, shift: shift, day: _day(shift)),
        _user(role: 'admin'),
      ),
    );
    await tester.pump();

    // Nhãn missed hiển thị (badge + dòng Trạng thái).
    expect(find.text('Bỏ qua ca'), findsWidgets);
    // Đường chốt ra bằng hành động check-out thường.
    expect(find.text('Xác nhận Ra ca'), findsOneWidget);
  });

  testWidgets('Manager thấy đường chốt ra cho ca bị bỏ qua (missed)', (tester) async {
    final staff = _missedStaff();
    final shift = _shift(staff);
    await tester.pumpWidget(
      _host(
        StaffGeneralShiftDetailScreen(staff: staff, shift: shift, day: _day(shift)),
        _user(role: 'manager'),
      ),
    );
    await tester.pump();

    expect(find.text('Xác nhận Ra ca'), findsOneWidget);
  });

  testWidgets('Staff KHÔNG thấy đường chốt ra cho ca bị bỏ qua', (tester) async {
    final staff = _missedStaff();
    final shift = _shift(staff);
    await tester.pumpWidget(
      _host(
        StaffGeneralShiftDetailScreen(staff: staff, shift: shift, day: _day(shift)),
        _user(role: 'staff'),
      ),
    );
    await tester.pump();

    expect(find.text('Xác nhận Ra ca'), findsNothing);
    // Staff chỉ thấy lời hướng dẫn liên hệ quản lý/admin, không có hành động chốt.
    expect(find.textContaining('liên hệ quản lý hoặc admin'), findsOneWidget);
  });

  testWidgets('Chốt ca bị bỏ qua gọi check-out với shiftId và hiện đúng message backend',
      (tester) async {
    final staff = _missedStaff();
    final shift = _shift(staff);
    const backendMsg =
        'Bạn chỉ chốt được ca của chi nhánh mình quản lý';

    final mockApi = MockApiClient();
    mockApi.postJsonHandler = (path, payload) {
      throw const ApiException('FORBIDDEN', backendMsg, 403);
    };

    // Nút nằm cuối SingleChildScrollView; mở rộng surface để nó nằm trong
    // viewport, nếu không tap() sẽ rơi ra ngoài và không kích hoạt handler.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        StaffGeneralShiftDetailScreen(
          staff: staff,
          shift: shift,
          day: _day(shift),
          attendance: AttendanceRepository(api: mockApi),
        ),
        _user(role: 'manager'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Xác nhận Ra ca'));
    await tester.pump();

    // Payload: chốt hộ bằng check-out thường, bắt buộc có shiftId dòng ca,
    // không gửi attendanceId (dễ đóng nhầm bản ghi khác).
    final req = mockApi.requests.last;
    expect(req.path, '/api/attendance/checkout');
    expect(req.payload?['employeeId'], 'emp-1');
    expect(req.payload?['shiftId'], 'shift-row-1');
    expect(req.payload?.containsKey('attendanceId'), isFalse);
    expect(req.payload?['checkoutTime'], matches(RegExp(r'^\d{2}:\d{2}$')));

    // Message của backend (envelope error.message) hiện nguyên văn, không tự chế.
    expect(find.text(backendMsg), findsOneWidget);
  });
}
