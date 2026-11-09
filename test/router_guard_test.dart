import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/router/router.dart';
import 'package:mobile/src/features/home/main_nav.dart';

void main() {
  // Không pumpAndSettle: splash có CircularProgressIndicator chạy vô hạn.
  testWidgets('/main thiếu extra thì redirect về splash, không dựng shell', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: AppRouter.router));
    await tester.pump();

    AppRouter.router.go('/main');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MainNavigationScreen), findsNothing);
    expect(AppRouter.router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('/main có UserModel thật thì vào được shell', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: AppRouter.router));
    await tester.pump();

    AppRouter.router.go('/main', extra: const UserModel(
      id: 'NV-TEST',
      name: 'Người Dùng Test',
      email: 'test@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(AppRouter.router.routeInformationProvider.value.uri.path, '/main');
  });

  tearDown(() {
    // Router là static dùng chung, trả về vị trí đầu để không ảnh hưởng test khác.
    AppRouter.router.go('/');
  });
}