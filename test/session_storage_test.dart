import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';

// Keychain/Keystore thật không có trong test: mock đúng MethodChannel của
// flutter_secure_storage bằng một Map để soi chính xác những gì được ghi/xóa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const accessKey = 'hrm.accessToken';
  const refreshKey = 'hrm.refreshToken';
  final store = <String, String>{};

  setUp(() {
    store.clear();
    ApiClient.clearSession();
    ApiClient.onSessionExpired = null;
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
        case 'containsKey':
          return store.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(store);
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ApiClient.clearSession();
    ApiClient.onSessionExpired = null;
    await ApiClient.clearPersistedSession();
  });

  test('remember: true ghi cả access + refresh token', () async {
    ApiClient().setSession(accessToken: 'access-abc', refreshToken: 'refresh-xyz');
    await ApiClient.persistSession(remember: true);

    expect(store[accessKey], 'access-abc');
    expect(store[refreshKey], 'refresh-xyz');
  });

  test('restoreSession trả false khi chưa lưu gì', () async {
    expect(await ApiClient.restoreSession(), isFalse);
  });

  test('remember: false không ghi và xóa bản đã lưu trước đó', () async {
    ApiClient().setSession(accessToken: 'access-abc', refreshToken: 'refresh-xyz');
    await ApiClient.persistSession(remember: true);
    expect(store, isNotEmpty);

    await ApiClient.persistSession(remember: false);
    expect(store, isEmpty);
    expect(await ApiClient.restoreSession(), isFalse);
  });

  test('clearPersistedSession xóa sạch và restoreSession hết nạp được', () async {
    store[accessKey] = 'access-stored';
    store[refreshKey] = 'refresh-stored';

    await ApiClient.clearPersistedSession();

    expect(store, isEmpty);
    expect(await ApiClient.restoreSession(), isFalse);
  });

  test('không có access token thì không ghi gì dù remember bật', () async {
    ApiClient().setSession(refreshToken: 'refresh-only');
    await ApiClient.persistSession(remember: true);

    expect(store, isEmpty);
  });

  // Mobile chỉ lưu token (Bearer); không có chỗ nào cho cookie hrm-session.
  test('chỉ lưu access/refresh/deviceSession, không lưu cookie', () async {
    ApiClient().setSession(
      accessToken: 'access-abc',
      refreshToken: 'refresh-xyz',
      deviceSessionId: 'device-1',
    );
    await ApiClient.persistSession(remember: true);

    expect(store.keys.toSet(), {accessKey, refreshKey, 'hrm.deviceSessionId'});
  });
}