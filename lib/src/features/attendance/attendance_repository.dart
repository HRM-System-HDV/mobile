import '../../core/models/attendance.dart';
import '../../core/network/api_client.dart';

/// Repository chấm công gọi qua api-gateway (4000) về work-service (4003).
///
/// Body chỉ được chứa đúng các khóa WorkService cho phép
/// (`employeeId`, `shiftId`, `wifi`), mọi khóa thừa đều bị backend trả 400
/// "Thuộc tính không hỗ trợ". Giờ vào/ra do server tính, client không gửi.
class AttendanceRepository {
  final ApiClient api;
  AttendanceRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// Wi-Fi là MỘT object `{ssid, bssid}`, không phải hai khóa rời.
  static Map<String, dynamic> _wifi({String? ssid, String? bssid}) => {
        if (ssid != null) 'ssid': ssid,
        if (bssid != null) 'bssid': bssid,
      };

  Future<AttendanceModel> checkIn({
    required String employeeId,
    required String shiftId,
    String? wifiSsid,
    String? wifiBssid,
  }) async {
    final res = await api.postJson('/api/attendance/checkin', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      'wifi': _wifi(ssid: wifiSsid, bssid: wifiBssid),
    });
    return AttendanceModel.fromJson(_asMap(res));
  }

  Future<AttendanceModel> checkOut({
    required String employeeId,
    required String shiftId,
    String? wifiSsid,
    String? wifiBssid,
  }) async {
    final res = await api.postJson('/api/attendance/checkout', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      'wifi': _wifi(ssid: wifiSsid, bssid: wifiBssid),
    });
    return AttendanceModel.fromJson(_asMap(res));
  }

  /// Đọc cấu hình chấm công. Lỗi mạng/403 KHÔNG được nuốt thành cấu hình rỗng
  /// (màn sẽ hiện mặc định 5 phút / 60 phút như thật): lỗi được ném lên cho
  /// tầng trên hiển thị.
  Future<Map<String, dynamic>> getConfig() async {
    final res = await api.getJson('/api/attendance/config');
    return _asMap(res);
  }

  /// `workDate` dạng YYYY-MM-DD, `month` dạng YYYY-MM — backend không nhận
  /// khóa `date` và cũng không còn `branchSlug`.
  Future<List<AttendanceModel>> getAttendance({
    String? employeeId,
    String? workDate,
    String? month,
    String? branchId,
  }) async {
    final query = <String, String>{};
    if (employeeId != null && employeeId.isNotEmpty) query['employeeId'] = employeeId;
    if (workDate != null && workDate.isNotEmpty) query['workDate'] = workDate;
    if (month != null && month.isNotEmpty) query['month'] = month;
    if (branchId != null && branchId.isNotEmpty) query['branchId'] = branchId;

    final data = await api.getJson('/api/attendance', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceModel.fromJson)
        .toList();
  }

  /// api_client đã bóc envelope `{data}`, repository không bóc lần hai.
  static Map<String, dynamic> _asMap(dynamic res) =>
      res is Map<String, dynamic> ? res : const {};
}
