import '../../core/models/branch.dart';
import '../../core/models/device_session.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../profile/employee_repository.dart';

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
    final slug = j['branchSlug']?.toString() ?? j['branch']?.toString() ?? '';
    final branch = slug.isNotEmpty ? branchById(slug) : null;
    final branchSlug = branch?.slug ?? (slug.isNotEmpty ? slug : null);
    return UserModel(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      role: j['role']?.toString() ?? 'staff',
      roleTitle: j['roleTitle']?.toString() ?? '',
      assignedBranchId: branchSlug,
      branchSlug: branchSlug,
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
      avatarUrl: j['avatarUrl']?.toString() ?? j['avatar']?.toString(),
      cccdFrontUrl: j['cccdFrontUrl']?.toString() ?? j['cccdFront']?.toString(),
      cccdBackUrl: j['cccdBackUrl']?.toString() ?? j['cccdBack']?.toString(),
    );
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
    var userModel = _toUser(user);
    // Đồng bộ hồ sơ chi tiết (avatar, CCCD, thông tin ngân hàng) từ organization-service
    if (userModel.id.isNotEmpty) {
      try {
        final profile = await EmployeeRepository(api: api).getEmployee(userModel.id);
        if (profile != null) {
          userModel = userModel.copyWith(
            avatarUrl: profile['avatar']?.toString() ?? userModel.avatarUrl,
            phone: profile['phone']?.toString() ?? userModel.phone,
            gender: profile['gender']?.toString() ?? userModel.gender,
            birthDate: profile['birthDate']?.toString() ?? userModel.birthDate,
            province: profile['province']?.toString() ?? userModel.province,
            ward: profile['ward']?.toString() ?? userModel.ward,
            street: profile['street']?.toString() ?? userModel.street,
            cccd: profile['cccd']?.toString() ?? userModel.cccd,
            issueDate: profile['issueDate']?.toString() ?? userModel.issueDate,
            issuePlace: profile['issuePlace']?.toString() ?? userModel.issuePlace,
            cccdFrontUrl: profile['cccdFront']?.toString() ?? userModel.cccdFrontUrl,
            cccdBackUrl: profile['cccdBack']?.toString() ?? userModel.cccdBackUrl,
            bankName: profile['bankName']?.toString() ?? userModel.bankName,
            bankAccountNumber: profile['bankAccountNumber']?.toString() ?? userModel.bankAccountNumber,
            bankAccountName: profile['bankAccountName']?.toString() ?? userModel.bankAccountName,
          );
        }
      } catch (_) {}
    }
    return userModel;
  }

  /// Lấy phiên hiện tại. Trả về null khi chưa/chưa còn đăng nhập.
  Future<UserModel?> me() async {
    try {
      final data = await api.getJson('/api/auth/me');
      // Tiền tải trước danh sách chi nhánh từ DB thật
      try {
        await EmployeeRepository(api: api).getBranches();
      } catch (_) {}
      var userModel = _toUser((data as Map).cast<String, dynamic>());
      // Đồng bộ hồ sơ chi tiết (avatar, CCCD, thông tin ngân hàng) từ organization-service
      if (userModel.id.isNotEmpty) {
        try {
          final profile = await EmployeeRepository(api: api).getEmployee(userModel.id);
          if (profile != null) {
            userModel = userModel.copyWith(
              avatarUrl: profile['avatar']?.toString() ?? userModel.avatarUrl,
              phone: profile['phone']?.toString() ?? userModel.phone,
              gender: profile['gender']?.toString() ?? userModel.gender,
              birthDate: profile['birthDate']?.toString() ?? userModel.birthDate,
              province: profile['province']?.toString() ?? userModel.province,
              ward: profile['ward']?.toString() ?? userModel.ward,
              street: profile['street']?.toString() ?? userModel.street,
              cccd: profile['cccd']?.toString() ?? userModel.cccd,
              issueDate: profile['issueDate']?.toString() ?? userModel.issueDate,
              issuePlace: profile['issuePlace']?.toString() ?? userModel.issuePlace,
              cccdFrontUrl: profile['cccdFront']?.toString() ?? userModel.cccdFrontUrl,
              cccdBackUrl: profile['cccdBack']?.toString() ?? userModel.cccdBackUrl,
              bankName: profile['bankName']?.toString() ?? userModel.bankName,
              bankAccountNumber: profile['bankAccountNumber']?.toString() ?? userModel.bankAccountNumber,
              bankAccountName: profile['bankAccountName']?.toString() ?? userModel.bankAccountName,
            );
          }
        } catch (_) {}
      }
      return userModel;
    } on ApiException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Gửi refresh token để backend thu hồi phiên thật, không chỉ xóa cookie.
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


