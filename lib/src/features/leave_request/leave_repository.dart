import '../../core/models/leave_request.dart';
import '../../core/network/api_client.dart';

/// Repository đơn từ gọi qua api-gateway về integration-service (4005).
class LeaveRepository {
  final ApiClient api;
  LeaveRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<LeaveRequestModel>> getRequests({String? employeeId}) async {
    final data = await api.getJson('/api/requests', query: {
      if (employeeId != null) 'employeeId': employeeId,
    });
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromJson)
        .toList();
  }

  Future<LeaveRequestModel> createRequest(Map<String, dynamic> payload) async {
    final data = await api.postJson('/api/requests', payload);
    return LeaveRequestModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
