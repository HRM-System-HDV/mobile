import '../../core/models/attendance.dart';
import '../../core/network/api_client.dart';

/// Repository chấm công gọi qua api-gateway (4000) về work-service (4003).
class AttendanceRepository {
  final ApiClient api;
  AttendanceRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<AttendanceModel> checkIn({
    required String employeeId,
    required String shiftId,
    String? wifiSsid,
    String? checkinTime,
  }) async {
    final res = await api.postJson('/api/attendance/checkin', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
      if (checkinTime != null) 'checkinTime': checkinTime,
    });
    final Map<String, dynamic> data = res is Map<String, dynamic> ? res : {};
    return AttendanceModel.fromJson(data);
  }

  Future<AttendanceModel> checkOut({
    String? attendanceId,
    String? employeeId,
    String? shiftId,
    String? checkoutTime,
  }) async {
    final res = await api.postJson('/api/attendance/checkout', {
      if (attendanceId != null) 'attendanceId': attendanceId,
      if (employeeId != null) 'employeeId': employeeId,
      if (shiftId != null) 'shiftId': shiftId,
      if (checkoutTime != null) 'checkoutTime': checkoutTime,
    });
    final Map<String, dynamic> data = res is Map<String, dynamic> ? res : {};
    return AttendanceModel.fromJson(data);
  }

  Future<List<AttendanceModel>> getAttendance({
    String? employeeId,
    String? date,
  }) async {
    final query = <String, String>{};
    if (employeeId != null) query['employeeId'] = employeeId;
    if (date != null) query['date'] = date;

    final data = await api.getJson('/api/attendance', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceModel.fromJson)
        .toList();
  }
}
