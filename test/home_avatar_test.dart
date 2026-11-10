import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/config/company.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/core/utils/image_helper.dart';
import 'package:mobile/src/features/home/home.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

UserModel _user({String? avatarUrl}) => UserModel(
      id: 'e-admin',
      name: 'Trần Hoàng Đạt',
      email: 'thd@gmail.com',
      role: 'admin',
      roleTitle: 'Quản trị viên',
      avatarUrl: avatarUrl,
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
  testWidgets('Header trang chủ render ảnh đại diện đã đồng bộ từ API', (tester) async {
    await _pumpHome(tester, _user(avatarUrl: 'data:image/png;base64,$_pngBase64'));

    final avatar = tester.widget<Image>(
      find.descendant(of: find.byType(ClipOval), matching: find.byType(Image)).first,
    );
    expect(avatar.image, isA<MemoryImage>());
    expect((avatar.image as MemoryImage).bytes, base64Decode(_pngBase64));
    expect(find.text('Trần Hoàng Đạt'), findsOneWidget);
  });

  testWidgets('Hồ sơ chưa có ảnh thì hiện icon vai trò', (tester) async {
    await _pumpHome(tester, _user());

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsWidgets);
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