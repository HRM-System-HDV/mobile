import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/auth/auth_repository.dart';

// Test đấu API thật: cần identity (4001) + gateway (4000) đang chạy.
// Bỏ qua khi không có server để không làm đỏ CI.
void main() {
  tearDown(() => ApiClient.clearSession());

  test('login + me thật qua gateway: chỉ dùng Authorization: Bearer', () async {
    final api = ApiClient(baseUrl: 'http://localhost:4000');
    final repo = AuthRepository(api: api);
    late UserModel logged;
    try {
      logged = await repo.login('admin@company.com', '123456');
    } catch (_) {
      markTestSkipped('Gateway/identity chưa chạy, bỏ qua test live');
      return;
    }
    expect(logged.email, 'admin@company.com');
    // systemRole là nguồn quyết định vai trò, role chỉ là fallback.
    expect(logged.role, 'admin');
    expect(logged.id.isNotEmpty, isTrue);

    final me = await repo.me();
    expect(me?.email, 'admin@company.com');
    expect(me?.id, logged.id);
    expect(me?.employeeId, logged.employeeId);
  });
}
