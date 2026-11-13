import '../../core/models/device_session.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../profile/employee_repository.dart';

/// Tầng data cho Auth: gọi API thật qua api-gateway về identity-service.
///
/// - Đăng nhập: `POST /api/auth/login` (chỉ dùng `Authorization: Bearer`).
/// - Kiểm tra phiên: `GET /api/auth/me`.
/// - Đăng xuất: `POST /api/auth/logout`.
/// - Đổi mật khẩu: `POST /api/auth/change-password`.
/// - Quên mật khẩu: `POST /api/auth/forgot-password`.
/// - Thiết bị: `GET /api/auth/devices` & `DELETE /api/auth/devices/:id`.
class AuthRepository {
  final ApiClient api;
  AuthRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// `toSafeUser` chỉ trả id, employeeId, email, name, systemRole, role,
  /// branchId. `systemRole` là quyền quyết định vai trò, `role` chỉ là fallback.
  UserModel _toUser(Map<String, dynamic> j) {
    return UserModel(
      id: j['id']?.toString() ?? '',
      employeeId: j['employeeId']?.toString(),
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      role: j['systemRole']?.toString() ?? j['role']?.toString() ?? 'staff',
      assignedBranchId: j['branchId']?.toString(),
    );
  }

  /// Hồ sơ chi tiết (địa chỉ, CCCD, ngân hàng) lấy từ organization-service
  /// theo **employeeId** — truyền id tài khoản vào đây sẽ bị backend chặn 403.
  Future<UserModel> _withEmployeeProfile(UserModel userModel) async {
    final employeeId = userModel.employeeId;
    if (employeeId == null || employeeId.isEmpty) return userModel;
    try {
      final profile = await EmployeeRepository(api: api).getEmployee(employeeId);
      if (profile == null) return userModel;
      return userModel.copyWith(
        gender: profile['gender']?.toString(),
        birthDate: profile['birthDate']?.toString(),
        province: profile['province']?.toString(),
        ward: profile['ward']?.toString(),
        street: profile['street']?.toString(),
        cccd: profile['cccd']?.toString(),
        issueDate: profile['issueDate']?.toString(),
        issuePlace: profile['issuePlace']?.toString(),
        salaryType: profile['salaryType']?.toString(),
        cccdBackUrl: profile['cccdBack']?.toString(),
        bankName: profile['bankName']?.toString(),
        bankAccountNumber: profile['bankAccountNumber']?.toString(),
        bankAccountName: profile['bankAccountName']?.toString(),
      );
    } catch (_) {
      return userModel;
    }
  }

  /// Đăng nhập bằng email + mật khẩu, trả về user từ server.
  /// [rememberMe] quyết định có ghi token vào Keychain/Keystore hay không.
  Future<UserModel> login(String email, String password, {bool rememberMe = false}) async {
    final data = await api.postJson('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    if (data is Map && data.containsKey('accessToken')) {
      api.setSession(
        accessToken: data['accessToken']?.toString(),
        refreshToken: data['refreshToken']?.toString(),
        deviceSessionId: data['deviceSessionId']?.toString(),
      );
    }
    await ApiClient.persistSession(remember: rememberMe);
    // Tiền tải trước danh sách chi nhánh từ DB thật
    try {
      await EmployeeRepository(api: api).getBranches();
    } catch (_) {}
    final user = (data as Map)['user'] as Map<String, dynamic>;
    return _withEmployeeProfile(_toUser(user));
  }

  /// Lấy phiên hiện tại. Trả về null khi chưa/chưa còn đăng nhập.
  Future<UserModel?> me() async {
    try {
      final data = await api.getJson('/api/auth/me');
      // Tiền tải trước danh sách chi nhánh từ DB thật
      try {
        await EmployeeRepository(api: api).getBranches();
      } catch (_) {}
      return await _withEmployeeProfile(_toUser((data as Map).cast<String, dynamic>()));
    } on ApiException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Gửi refresh token để backend thu hồi phiên thật.
      await api.postJson('/api/auth/logout', {
        'refreshToken': ApiClient.currentRefreshToken ?? '',
      });
    } on ApiException {
      // Mất mạng vẫn cho đăng xuất cục bộ để không kẹt phiên.
    }
    // Xóa sau khi gọi API để request logout vẫn còn token xác thực.
    ApiClient.clearSession();
    await ApiClient.clearPersistedSession();
  }

  /// Đổi mật khẩu tài khoản
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await api.postJson('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Xin cấp lại mật khẩu. Hệ thống không tự reset: quản trị viên sẽ cấp mật khẩu tạm.
  Future<String> forgotPassword(String email) async {
    final res = await api.postJson('/api/auth/forgot-password', {
      'email': email.trim(),
    });
    return (res as Map?)?['message']?.toString() ??
        'Vui lòng liên hệ quản trị viên hoặc quản lý để được cấp lại mật khẩu.';
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
