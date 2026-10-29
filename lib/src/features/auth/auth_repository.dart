import '../../core/models/branch.dart';
import '../../core/models/device_session.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';

/// Tầng data cho Auth: gọi API thật qua api-gateway về identity-service.
///
/// - Đăng nhập: `POST /api/auth/login` (server set cookie `hrm-session`).
/// - Kiểm tra phiên: `GET /api/auth/me`.
/// - Đăng xuất: `POST /api/auth/logout`.
/// - Đổi mật khẩu: `POST /api/auth/change-password`.
/// - Quên mật khẩu: `POST /api/auth/forgot-password`.
/// - Thiết bị: `GET /api/auth/devices` & `DELETE /api/auth/devices/:id`.
class AuthRepository {
  final ApiClient api;
  AuthRepository({ApiClient? api}) : api = api ?? ApiClient();

  UserModel _toUser(Map<String, dynamic> j) {
    final slug = (j['branchSlug']?.toString() ?? 'HN-1').toLowerCase();
    final branch = branchById(slug);
    return UserModel(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      role: j['role']?.toString() ?? 'staff',
      roleTitle: j['roleTitle']?.toString() ?? '',
      assignedBranchId: branch.id,
      gender: j['gender']?.toString() ?? '',
      birthDate: j['birthDate']?.toString() ?? '',
      province: j['province']?.toString() ?? '',
      ward: j['ward']?.toString() ?? '',
      street: j['street']?.toString() ?? '',
      cccd: j['cccd']?.toString() ?? '',
      issueDate: j['issueDate']?.toString() ?? '',
      issuePlace: j['issuePlace']?.toString() ?? '',
      salaryType: j['salaryType']?.toString() ?? 'hourly',
      hourlySalary: (j['hourlySalary'] as num?)?.toDouble() ?? 0.0,
      baseSalary: (j['baseSalary'] as num?)?.toDouble() ?? 0.0,
      bankName: j['bankName']?.toString() ?? '',
      bankAccountNumber: j['bankAccountNumber']?.toString() ?? '',
      bankAccountName: j['bankAccountName']?.toString() ?? '',
      avatarUrl: j['avatarUrl']?.toString(),
      cccdFrontUrl: j['cccdFrontUrl']?.toString(),
      cccdBackUrl: j['cccdBackUrl']?.toString(),
    );
  }

  /// Đăng nhập bằng email + mật khẩu, trả về user từ server.
  Future<UserModel> login(String email, String password) async {
    final data = await api.postJson('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final user = (data as Map)['user'] as Map<String, dynamic>;
    return _toUser(user);
  }

  /// Lấy phiên hiện tại. Trả về null khi chưa/chưa còn đăng nhập.
  Future<UserModel?> me() async {
    try {
      final data = await api.getJson('/api/auth/me');
      return _toUser((data as Map).cast<String, dynamic>());
    } on ApiException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await api.postJson('/api/auth/logout', {});
    } on ApiException {
      // Mất mạng vẫn cho đăng xuất cục bộ để không kẹt phiên.
    }
  }

  /// Đổi mật khẩu tài khoản
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await api.postJson('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Yêu cầu đặt lại mật khẩu về mặc định
  Future<String> forgotPassword(String email) async {
    final res = await api.postJson('/api/auth/forgot-password', {
      'email': email.trim(),
    });
    return (res as Map?)?['message']?.toString() ?? 'Mật khẩu đã được đặt lại về 123456';
  }

  /// Lấy danh sách thiết bị đang đăng nhập
  Future<List<DeviceSession>> getDevices() async {
    final data = await api.getJson('/api/auth/devices');
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DeviceSession.fromJson)
        .toList();
  }

  /// Gỡ phiên thiết bị từ xa
  Future<void> revokeDevice(String deviceId) async {
    await api.delete('/api/auth/devices/$deviceId');
  }
}


