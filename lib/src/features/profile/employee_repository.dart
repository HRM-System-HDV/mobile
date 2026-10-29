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
      final data = await api.getJson('/api/employees/$id');
      if (data is Map<String, dynamic>) return data;
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

  /// Lấy danh sách chi nhánh từ /api/branches (kèm fallback kBranches)
  Future<List<Branch>> getBranches() async {
    try {
      final data = await api.getJson('/api/branches');
      final List list = data is List ? data : [];
      if (list.isEmpty) return kBranches;
      return list.whereType<Map<String, dynamic>>().map((j) {
        final slug = (j['slug']?.toString() ?? 'hn-1').toLowerCase();
        final code = j['code']?.toString() ?? slug.toUpperCase();
        return Branch(
          id: j['id']?.toString() ?? code,
          slug: slug,
          code: code,
          name: j['name']?.toString() ?? 'Chi nhánh $code',
          address: j['address']?.toString() ?? '',
        );
      }).toList();
    } catch (_) {
      return kBranches;
    }
  }

  /// Yêu cầu thôi việc qua POST /api/employees/:id/leave
  Future<void> leaveJob(String id) async {
    try {
      await api.postJson('/api/employees/$id/leave', {});
    } catch (_) {
      // Fallback PUT status
      await api.putJson('/api/employees/$id', {'status': 'resigned'});
    }
  }
}
