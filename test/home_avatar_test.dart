import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/config/company.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/core/utils/image_helper.dart';
import 'package:mobile/src/features/home/home.dart';
import 'package:mobile/src/features/profile/employee_repository.dart';

import 'repositories/mock_api_client.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// `toSafeUser` (identity-service) không trả `avatarUrl`: ảnh đại diện nằm trong
/// hồ sơ organization-service. Vì vậy UserModel chỉ còn các cột thật.
UserModel _user() => const UserModel(
      id: 'e-admin',
      name: 'Trần Hoàng Đạt',
      email: 'thd@gmail.com',
      role: 'admin',
    );

Future<void> _pumpHome(WidgetTester tester, UserModel user) async {
  final notifier = ValueNotifier<UserModel?>(user);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: UserScope(
        notifier: notifier,
        child: HomeScreen(currentUser: user),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('Ảnh đại diện đồng bộ về từ GET /api/employees/:id và decode được', () async {
    final mock = MockApiClient();
    mock.getJsonResponse = {
      'id': 'e-admin',
      'avatar': 'data:image/png;base64,$_pngBase64',
    };

    final profile = await EmployeeRepository(api: mock).getEmployee('e-admin');

    expect(mock.requests.single.method, 'GET');
    expect(mock.requests.single.path, '/api/employees/e-admin');
    final provider = parseImageProvider(profile?['avatar']?.toString());
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, base64Decode(_pngBase64));
  });

  testWidgets('Hồ sơ chưa có ảnh thì header hiện icon vai trò', (tester) async {
    await _pumpHome(tester, _user());

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsWidgets);
    expect(find.text('Trần Hoàng Đạt'), findsOneWidget);
  });

  testWidgets('Đổi avatar trong UserScope thì header cập nhật theo', (tester) async {
    final user = _user();
    final notifier = ValueNotifier<UserModel?>(user);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: UserScope(
          notifier: notifier,
          child: HomeScreen(currentUser: user),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);

    notifier.value = user.copyWith(avatarUrl: 'data:image/png;base64,$_pngBase64');
    await tester.pump();
    expect(
      tester.widget<Image>(find.descendant(of: find.byType(ClipOval), matching: find.byType(Image)).first).image,
      isA<MemoryImage>(),
    );
  });

  test('Ảnh /api/files đi qua origin gateway của app và kèm JWT', () {
    ApiClient.clearSession();
    addTearDown(ApiClient.clearSession);
    ApiClient().setSession(accessToken: 'token-test');

    final provider =
        parseImageProvider('http://localhost:4000/api/files/hrm/avatars/abc') as NetworkImage;
    expect(provider.url, '${CompanyConfig.apiBaseUrl}/api/files/hrm/avatars/abc');
    expect(provider.headers?['Authorization'], 'Bearer token-test');
  });

  test('Ảnh CDN bên ngoài không bị gắn JWT của gateway', () {
    ApiClient.clearSession();
    addTearDown(ApiClient.clearSession);
    ApiClient().setSession(accessToken: 'token-test');

    final provider =
        parseImageProvider('https://res.cloudinary.com/demo/image/upload/avatar.jpg') as NetworkImage;
    expect(provider.url, 'https://res.cloudinary.com/demo/image/upload/avatar.jpg');
    expect(provider.headers, isNull);
  });
}