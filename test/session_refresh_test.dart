import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';

// Gateway giả chạy ngay trong test để luồng 401 -> refresh -> retry được kiểm
// chứng tất định, không cần identity-service đang bật.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  late HttpServer server;
  late ApiClient api;
  late List<String> seenAuth;
  late int refreshCalls;
  late int expiredCalls;

  setUp(() async {
    // Binding của flutter_test thay HTTP client bằng mock trả 400; ở đây cần
    // gọi server giả thật nên trả lại client mặc định.
    HttpOverrides.global = null;
    store.clear();
    ApiClient.clearSession();
    seenAuth = [];
    refreshCalls = 0;
    expiredCalls = 0;
    ApiClient.onSessionExpired = () => expiredCalls++;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          store[key!] = args['value'] as String;
          return null;
        case 'read':
          return store[key];
        case 'delete':
          store.remove(key);
          return null;
        default:
          return null;
      }
    });

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      res.headers.contentType = ContentType.json;
      if (req.uri.path == '/api/auth/refresh') {
        refreshCalls++;
        final body =
            jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        if (body['refreshToken'] != 'valid-refresh') {
          res.statusCode = 401;
          res.write(jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Refresh hết hạn'},
          }));
        } else {
          // Xoay cả hai token giống identity-service thật.
          res.write(jsonEncode({
            'data': {'accessToken': 'good-access', 'refreshToken': 'rotated-refresh'},
          }));
        }
      } else {
        seenAuth.add(req.headers.value('authorization') ?? '');
        if (req.headers.value('authorization') != 'Bearer good-access') {
          res.statusCode = 401;
          res.write(jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Phiên hết hạn'},
          }));
        } else {
          res.write(jsonEncode({
            'data': {'ok': true},
          }));
        }
      }
      await res.close();
    });

    api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ApiClient.clearSession();
    ApiClient.onSessionExpired = null;
    await ApiClient.clearPersistedSession();
  });

  test('restoreSession khiến request gửi đúng token đã lưu', () async {
    store['hrm.accessToken'] = 'good-access';
    store['hrm.refreshToken'] = 'valid-refresh';

    expect(await ApiClient.restoreSession(), isTrue);
    expect(await api.getJson('/api/me'), {'ok': true});
    expect(seenAuth, ['Bearer good-access']);
    expect(refreshCalls, 0);
  });

  test('401 thì refresh rồi gửi lại đúng một lần và thành công', () async {
    api.setSession(accessToken: 'stale-access', refreshToken: 'valid-refresh');

    expect(await api.getJson('/api/me'), {'ok': true});
    expect(seenAuth, ['Bearer stale-access', 'Bearer good-access']);
    expect(refreshCalls, 1);
    expect(expiredCalls, 0);
  });

  test('refresh xoay token thì bản lưu trong storage cũng được cập nhật', () async {
    api.setSession(accessToken: 'stale-access', refreshToken: 'valid-refresh');
    await ApiClient.persistSession(remember: true);

    await api.getJson('/api/me');

    expect(store['hrm.accessToken'], 'good-access');
    expect(store['hrm.refreshToken'], 'rotated-refresh');
  });

  test('refresh hỏng thì báo hết phiên một lần và xóa sạch token', () async {
    api.setSession(accessToken: 'stale-access', refreshToken: 'bad-refresh');
    await ApiClient.persistSession(remember: true);

    await expectLater(
      api.getJson('/api/me'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(refreshCalls, 1);
    expect(expiredCalls, 1);
    expect(store, isEmpty);
    expect(await ApiClient.restoreSession(), isFalse);
    // Chỉ thử lại sau refresh, không retry mù khi refresh đã hỏng.
    expect(seenAuth, ['Bearer stale-access']);
  });

  test('nhiều request cùng 401 chỉ kéo theo một lần refresh', () async {
    api.setSession(accessToken: 'stale-access', refreshToken: 'valid-refresh');

    final results = await Future.wait([
      api.getJson('/api/me'),
      api.getJson('/api/me'),
      api.getJson('/api/me'),
    ]);

    expect(results, [
      {'ok': true},
      {'ok': true},
      {'ok': true},
    ]);
    expect(refreshCalls, 1);
    expect(expiredCalls, 0);
  });

  test('không có refresh token thì hết phiên ngay, không gọi refresh', () async {
    api.setSession(accessToken: 'stale-access');

    await expectLater(api.getJson('/api/me'), throwsA(isA<ApiException>()));
    expect(refreshCalls, 0);
    expect(expiredCalls, 1);
  });
}