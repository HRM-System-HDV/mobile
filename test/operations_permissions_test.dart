import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/branch.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/state/branch_scope.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/features/tasks/operations.dart';

UserModel _user(String role) => UserModel(
      id: 'u-$role',
      name: 'User $role',
      email: '$role@company.com',
      role: role,
    );

Future<void> _pumpOperations(WidgetTester tester, UserModel user) async {
  // ListView dựng thẻ theo viewport: cấp chiều cao đủ lớn để mọi thẻ nằm trong
  // cây, nếu không findsNothing chỉ chứng minh thẻ chưa được build.
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final userNotifier = ValueNotifier<UserModel?>(user);
  final branchNotifier = ValueNotifier<Branch?>(null);
  addTearDown(userNotifier.dispose);
  addTearDown(branchNotifier.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: UserScope(
        notifier: userNotifier,
        child: BranchScope(
          notifier: branchNotifier,
          child: OperationsScreen(currentUser: user),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Admin thấy đủ thẻ quản trị gồm Cấu hình Wi-Fi', (tester) async {
    await _pumpOperations(tester, _user('admin'));

    expect(find.text('Nhân sự toàn công ty'), findsOneWidget);
    expect(find.text('Phê duyệt yêu cầu'), findsOneWidget);
    expect(find.text('Cấu hình Wi-Fi'), findsOneWidget);
  });

  testWidgets('Manager bị ẩn thẻ Wi-Fi dù vẫn thấy cụm Quản trị', (tester) async {
    await _pumpOperations(tester, _user('manager'));

    expect(find.text('Nhân sự chi nhánh'), findsOneWidget);
    expect(find.text('Duyệt yêu cầu chi nhánh'), findsOneWidget);
    expect(find.text('Cấu hình Wi-Fi'), findsNothing);
    expect(find.text('Wi-Fi chi nhánh'), findsNothing);
  });

  testWidgets('Staff bị ẩn trọn cụm Quản trị, chỉ còn luồng tự phục vụ', (tester) async {
    await _pumpOperations(tester, _user('staff'));

    expect(find.text('Phân ca làm việc'), findsNothing);
    // 'Giao việc' là badge của thẻ quản trị; staff vẫn thấy thẻ 'Việc của tôi'.
    expect(find.text('Giao việc'), findsNothing);
    expect(find.text('Cấu hình Wi-Fi'), findsNothing);
    expect(find.text('Kỳ lương & Phiếu lương cá nhân'), findsOneWidget);
    expect(find.text('Bảng tin & Thông báo'), findsOneWidget);
  });
}
