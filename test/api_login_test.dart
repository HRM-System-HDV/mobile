import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/auth/auth_repository.dart';

// Test đấu API thật: cần identity (4001) + gateway (4000) đang chạy.
// Bỏ qua khi không có server để không làm đỏ CI.
void main() {
  test('login + me thật qua gateway', () async {
    final api = ApiClient(baseUrl: 'http://localhost:4000');
    late Map<String, dynamic> user;
    try {
      final data = await api.postJson('/api/auth/login', {
        'email': 'admin@company.com',
        'password': '123456',
      });
      user = (data as Map)['user'] as Map<String, dynamic>;
    } catch (_) {
      markTestSkipped('Gateway/identity chưa chạy, bỏ qua test live');
      return;
    }
    expect(user['email'], 'admin@company.com');
    expect(user['role'], 'admin');

    final repo = AuthRepository(api: api);
    final me = await repo.me();
    expect(me?.email, 'admin@company.com');
  });
}
