import '../../core/models/attendance.dart';
import '../../core/network/api_client.dart';
import '../../core/services/attendance_wifi.dart';

/// Repository chấm công gọi qua api-gateway (4000) về work-service (4003).
///
/// Body chỉ được chứa đúng các khóa WorkService cho phép
/// (`employeeId`, `shiftId`, `wifi`), mọi khóa thừa đều bị backend trả 400
/// "Thuộc tính không hỗ trợ". Giờ vào/ra do server tính, client không gửi.
class AttendanceRepository {
  final ApiClient api;
  final AttendanceWifi wifi;
  AttendanceRepository({ApiClient? api, AttendanceWifi? wifi})
      : api = api ?? ApiClient(),
        wifi = wifi ?? AttendanceWifi();

  Future<AttendanceModel> checkInWithDeviceWifi(
      {required String employeeId, required String shiftId}) async {
    final network = await wifi.read();
    return checkIn(
        employeeId: employeeId,
        shiftId: shiftId,
        wifiSsid: network['ssid'],
        wifiBssid: network['bssid']);
  }

  Future<AttendanceModel> checkOutWithDeviceWifi(
      {required String employeeId, required String shiftId}) async {
    final network = await wifi.read();
    return checkOut(
        employeeId: employeeId,
        shiftId: shiftId,
        wifiSsid: network['ssid'],
        wifiBssid: network['bssid']);
  }

  Future<void> doubleAttendanceWithDeviceWifi({required String employeeId, required String shiftId, required String nextShiftId}) async {
    final network = await wifi.read();
    await api.postJson('/api/attendance/double', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      'nextShiftId': nextShiftId,
      'wifi': network,
    });
  }

  Future<AttendanceModel> saveAttendance(
      {required String shiftId,
      required DateTime checkIn,
      required DateTime checkOut,
      String? note}) async {
    final data = await api.putJson('/api/attendance/$shiftId', {
      'checkIn': checkIn.toUtc().toIso8601String(),
      'checkOut': checkOut.toUtc().toIso8601String(),
      if (note != null) 'penaltyNote': note,
    });
    return AttendanceModel.fromJson(_asMap(data));
  }

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
    if (employeeId != null && employeeId.isNotEmpty) {
      query['employeeId'] = employeeId;
    }
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
