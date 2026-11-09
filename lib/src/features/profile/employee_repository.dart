import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';

/// Repository quản lý Nhân sự & Chi nhánh gọi qua api-gateway (4000) về organization-service (4002).
class EmployeeRepository {
  final ApiClient api;
  EmployeeRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// Lấy danh sách nhân viên từ /api/employees (có thể lọc theo chi nhánh)
  Future<List<Map<String, dynamic>>> getEmployees({String? branchSlug}) async {
    final query = <String, String>{};
    if (branchSlug != null && branchSlug.isNotEmpty) {
      query['branchSlug'] = branchSlug;
    }
    final data = await api.getJson('/api/employees', query: query);
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Lấy chi tiết một nhân viên
  Future<Map<String, dynamic>?> getEmployee(String id) async {
    try {
      final res = await api.getJson('/api/employees/$id');
      if (res is Map && res['data'] is Map<String, dynamic>) {
        return (res['data'] as Map).cast<String, dynamic>();
      }
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cập nhật thông tin nhân viên qua PUT /api/employees/:id
  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await api.putJson('/api/employees/$id', payload);
    return res is Map<String, dynamic> ? res : {};
  }

  /// Lấy danh sách chi nhánh từ /api/branches từ backend thật.
  /// Ném lỗi khi API thất bại để nơi gọi phân biệt được dữ liệu mới với cache cũ.
  Future<List<Branch>> getBranches() async {
    final data = await api.getJson('/api/branches');
    final List list = data is List ? data : [];
    final result = list.whereType<Map<String, dynamic>>().map((j) {
      return Branch.fromJson(j);
    }).toList();
    updateBranchCache(result);
    return result;
  }

  /// Yêu cầu thôi việc qua POST /api/employees/:id/leave
  Future<void> leaveJob(String id) async {
    await api.postJson('/api/employees/$id/leave', {});
  }
}
