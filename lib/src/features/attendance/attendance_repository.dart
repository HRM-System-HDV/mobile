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
    String? wifiBssid,
    String? checkinTime,
  }) async {
    final res = await api.postJson('/api/attendance/checkin', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      if (wifiSsid != null) 'wifiSsid': wifiSsid,
      if (wifiBssid != null) 'wifiBssid': wifiBssid,
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

  /// Đọc cấu hình chấm công. Lỗi mạng/403 KHÔNG được nuốt thành cấu hình rỗng
  /// (màn sẽ hiện mặc định 5 phút / 60 phút như thật): lỗi được ném lên cho
  /// tầng trên hiển thị.
  Future<Map<String, dynamic>> getConfig() async {
    final res = await api.getJson('/api/attendance/config');
    if (res is Map<String, dynamic>) {
      final d = res['data'];
      if (d is Map<String, dynamic>) return d;
      return res;
    }
    return {};
  }

  Future<List<AttendanceModel>> getAttendance({
    String? employeeId,
    String? date,
    String? branchSlug,
  }) async {
    final query = <String, String>{};
    if (employeeId != null) query['employeeId'] = employeeId;
    if (date != null) query['date'] = date;
    if (branchSlug != null && branchSlug.isNotEmpty) query['branchSlug'] = branchSlug;

    final data = await api.getJson('/api/attendance', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceModel.fromJson)
        .toList();
  }
}
