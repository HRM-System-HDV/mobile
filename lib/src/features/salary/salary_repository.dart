import '../../core/models/payslip.dart';
import '../../core/models/payout.dart';
import '../../core/network/api_client.dart';

/// Repository lương gọi qua api-gateway về payroll-service (4004).
/// Lỗi mạng/service chưa sẵn sàng được ném [ApiException] để UI hiện empty state.
class SalaryRepository {
  final ApiClient api;
  SalaryRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<PayslipModel> getPayslip(String id) async {
    final data = await api.getJson('/api/payroll/payslips/${Uri.encodeComponent(id)}');
    if (data is! Map<String, dynamic> || data['id'] != id) {
      throw const ApiException('INVALID_RESPONSE', 'Dữ liệu chi tiết không hợp lệ', 502);
    }
    return PayslipModel.fromJson(data);
  }

  Future<List<PayslipModel>> getPayslips({String? employeeId, String? month}) async {
    final data = await api.getJson('/api/payroll/payslips', query: {
      if (employeeId != null) 'employeeId': employeeId,
      if (month != null) 'month': month,
    });
    final List list = data is List ? data : (data is Map && data['items'] is List ? data['items'] : []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PayslipModel.fromJson)
        .toList();
  }

  Future<List<PayoutModel>> getPayouts() async {
    final data = await api.getJson('/api/payroll/payouts');
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PayoutModel.fromJson)
        .toList();
  }
}
