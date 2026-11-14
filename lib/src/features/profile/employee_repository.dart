import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';

/// Repository quản lý Nhân sự & Chi nhánh gọi qua api-gateway (4000) về organization-service (4002).
class EmployeeRepository {
  final ApiClient api;
  EmployeeRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// Lấy danh sách nhân viên từ /api/employees (có thể lọc theo chi nhánh).
  /// Organization chỉ nhận bộ lọc id: branchId, departmentId, positionId, status.
  Future<Branch> getBranch(String id) async {
    final data = await api.getJson('/api/branches/${Uri.encodeComponent(id)}');
    if (data is! Map<String, dynamic> || data['id'] != id) {
      throw const ApiException('INVALID_RESPONSE', 'Dữ liệu chi tiết không hợp lệ', 502);
    }
    return Branch.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getEmployees({String? branchId}) async {
    final query = <String, String>{};
    if (branchId != null && branchId.isNotEmpty) {
      query['branchId'] = branchId;
    }
    final data = await api.getJson('/api/employees', query: query);
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Lấy chi tiết một nhân viên. Lỗi mạng/403 được ném lên để nơi gọi biết
  /// dữ liệu chưa tải được (trả null sẽ bị hiểu nhầm là "không có hồ sơ").
  Future<Map<String, dynamic>?> getEmployee(String id) async {
    final res = await api.getJson('/api/employees/$id');
    return res is Map<String, dynamic> ? res : null;
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
