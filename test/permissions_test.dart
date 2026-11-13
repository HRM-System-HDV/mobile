import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/config/permissions.dart';
import 'package:mobile/src/core/models/user.dart';

UserModel _user(String role) => UserModel(
      id: 'u-$role',
      name: 'User $role',
      email: '$role@company.com',
      role: role,
    );

void main() {
  group('Bảng phân quyền tính năng mobile', () {
    test('Cấu hình Wi-Fi là tính năng riêng Quản trị viên', () {
      expect(canAccessRoute(_user('admin'), '/wifi'), isTrue);
      expect(canAccessRoute(_user('manager'), '/wifi'), isFalse);
      expect(canAccessRoute(_user('staff'), '/wifi'), isFalse);
    });

    test('Tuyến quản trị mở cho admin + manager, đóng với staff', () {
      for (final route in ['/tasks/monitor', '/approvals', '/schedule/assignment']) {
        expect(canAccessRoute(_user('admin'), route), isTrue, reason: route);
        expect(canAccessRoute(_user('manager'), route), isTrue, reason: route);
        expect(canAccessRoute(_user('staff'), route), isFalse, reason: route);
      }
    });

    test('Luồng tự phục vụ để mở cho cả ba vai trò', () {
      for (final role in ['admin', 'manager', 'staff']) {
        for (final route in [
          '/salary',
          '/leave',
          '/schedule/general',
          '/schedule/registration',
          '/tasks',
          '/news',
          '/regulations',
          '/attendance/adjustment',
        ]) {
          expect(canAccessRoute(_user(role), route), isTrue, reason: '$role $route');
        }
      }
    });

    test('Chức danh lạ và phiên chưa resolve đều quy về staff', () {
      expect(normalizeRole('Trưởng phòng'), 'staff');
      expect(roleOf(null), 'staff');
      expect(canAccessRoute(null, '/wifi'), isFalse);
      expect(canAccessRoute(null, '/approvals'), isFalse);
      expect(canAccessRoute(null, '/salary'), isTrue);
    });

    test('Câu báo quyền nêu đúng vai trò được phép', () {
      expect(permissionHintFor('/wifi'), 'Chức năng này chỉ dành cho Quản trị viên.');
      expect(
        permissionHintFor('/approvals'),
        'Chức năng này chỉ dành cho Quản trị viên và Quản lý Chi nhánh.',
      );
    });
  });
}
