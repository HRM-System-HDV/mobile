import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/config/permissions.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/router/router.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/core/widgets/no_access_screen.dart';

UserModel _user(String role) => UserModel(
      id: 'u-$role',
      name: 'User $role',
      email: '$role@company.com',
      role: role,
      roleTitle: 'Nhân viên',
    );

Future<void> _pumpApp(WidgetTester tester, UserModel? user) async {
  final notifier = ValueNotifier<UserModel?>(user);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: AppRouter.router,
      builder: (context, child) => UserScope(
        notifier: notifier,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _expectBlocked(WidgetTester tester, UserModel user, String route) async {
  await _pumpApp(tester, user);
  AppRouter.router.go(route);
  await tester.pump();

  expect(find.byType(NoAccessScreen), findsOneWidget, reason: route);
  expect(find.text(permissionHintFor(route)), findsOneWidget, reason: route);
}

void main() {
  tearDown(() {
    // Router là static dùng chung, trả về splash để không ảnh hưởng test khác.
    AppRouter.router.go('/');
  });

  testWidgets('Manager đi thẳng vào /wifi vẫn bị chặn, không vào màn cấu hình', (tester) async {
    await _expectBlocked(tester, _user('manager'), '/wifi');
  });

  testWidgets('Staff đi thẳng vào các tuyến quản trị đều bị chặn', (tester) async {
    for (final route in ['/approvals', '/tasks/monitor', '/schedule/assignment', '/wifi']) {
      await _expectBlocked(tester, _user('staff'), route);
    }
  });

  testWidgets('guardRoute chỉ dựng màn tính năng khi vai trò được phép', (tester) async {
    for (final entry in kRoleRestrictedRoutes.entries) {
      for (final role in ['admin', 'manager', 'staff']) {
        final notifier = ValueNotifier<UserModel?>(_user(role));
        addTearDown(notifier.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: UserScope(
              notifier: notifier,
              child: Builder(
                builder: (context) => Scaffold(
                  body: guardRoute(context, entry.key, const Text('MAN_HINH')),
                ),
              ),
            ),
          ),
        );
        final allowed = canAccessRoute(_user(role), entry.key);
        expect(
          find.text('MAN_HINH'),
          allowed ? findsOneWidget : findsNothing,
          reason: '${entry.key} / $role',
        );
        expect(
          find.byType(NoAccessScreen),
          allowed ? findsNothing : findsOneWidget,
          reason: '${entry.key} / $role',
        );
      }
    }
  });
}
