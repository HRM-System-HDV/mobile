import '../../core/models/attendance.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';

/// Ngày gửi backend phải là YYYY-MM-DD (work-service từ chối DD/MM/YYYY).
String toIsoDate(String? raw) {
  final d = parseVnDate(raw);
  if (d == null) return raw?.trim() ?? '';
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Ca làm việc — đúng bản ghi `shifts` mà work-service trả về, cộng phần chấm
/// công do `shiftProjection` gắn thêm (`attendance`, `attendanceState`,
/// `canCheckout`).
///
/// `status` là vòng đời của ca: "đang làm" | "đã hủy" (không còn
/// `isRecurring`). Kết quả chấm công nằm ở `attendance.status`.
class ApiShiftModel {
  final String id;
  final String? employeeId;

  /// `shifts` không có cột chi nhánh; branchId chỉ có trên đăng ký/nguyện vọng.
  final String? branchId;

  /// Ngày làm việc, định dạng YYYY-MM-DD.
  final String workDate;
  final String templateId;
  final String scheduledStart;
  final String scheduledEnd;
  final String status;
  final String? note;
  final AttendanceModel? attendance;

  /// not_started | working | completed | missed_checkin | missed_checkout
  final String attendanceState;

  /// Backend đã tính cửa sổ check-out: UI chỉ được cho ra ca khi cờ này true.
  final bool canCheckout;

  const ApiShiftModel({
    required this.id,
    this.employeeId,
    this.branchId,
    required this.workDate,
    required this.templateId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.status = 'đang làm',
    this.note,
    this.attendance,
    this.attendanceState = 'not_started',
    this.canCheckout = false,
  });

  factory ApiShiftModel.fromJson(Map<String, dynamic> j) {
    final rawAttendance = j['attendance'];
    return ApiShiftModel(
      id: j['id']?.toString() ?? '',
      employeeId: j['employeeId']?.toString(),
      branchId: j['branchId']?.toString(),
      workDate: j['workDate']?.toString() ?? '',
      templateId: j['templateId']?.toString() ?? '',
      scheduledStart: j['scheduledStart']?.toString() ?? '',
      scheduledEnd: j['scheduledEnd']?.toString() ?? '',
      status: j['status']?.toString() ?? 'đang làm',
      note: j['note']?.toString(),
      attendance: rawAttendance is Map<String, dynamic>
          ? AttendanceModel.fromJson(rawAttendance)
          : null,
      attendanceState: j['attendanceState']?.toString() ?? 'not_started',
      canCheckout: j['canCheckout'] == true,
    );
  }

  /// Giờ vào/ra thực tế thuộc bản ghi chấm công, không phải cột của ca.
  String? get checkIn => attendance?.checkIn;
  String? get checkOut => attendance?.checkOut;
  bool get isCancelled => status == 'đã hủy';

  String get timeLabel =>
      (scheduledStart.isEmpty || scheduledEnd.isEmpty) ? '—' : '$scheduledStart - $scheduledEnd';

  /// Chỉ chứa các khóa mà createShift/updateShift chấp nhận.
  Map<String, dynamic> toJson() => {
        if (employeeId != null) 'employeeId': employeeId,
        if (templateId.isNotEmpty) 'templateId': templateId,
        if (workDate.isNotEmpty) 'workDate': toIsoDate(workDate),
        if (note != null) 'note': note,
        if (status.isNotEmpty) 'status': status,
      };
}

/// Repository ca làm việc gọi qua api-gateway (4000) về work-service (4003).
class ShiftRepository {
  final ApiClient api;
  ShiftRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// `workDate` YYYY-MM-DD, `month` YYYY-MM; lọc theo chi nhánh dùng `branchId`.
  Future<List<ApiShiftModel>> getShifts({
    String? branchId,
    String? employeeId,
    String? workDate,
    String? month,
  }) async {
    final query = <String, String>{};
    if (branchId != null && branchId.isNotEmpty) query['branchId'] = branchId;
    if (employeeId != null && employeeId.isNotEmpty) query['employeeId'] = employeeId;
    if (workDate != null && workDate.isNotEmpty) query['workDate'] = toIsoDate(workDate);
    if (month != null && month.isNotEmpty) query['month'] = month;

    final data = await api.getJson('/api/shifts', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiShiftModel.fromJson)
        .toList();
  }

  /// Backend tự suy ra scheduledStart/End từ ca mẫu và tự đặt trạng thái, nên
  /// body tạo ca chỉ có employeeId, templateId, workDate, note.
  Future<ApiShiftModel> createShift({
    required String employeeId,
    required String templateId,
    required String workDate,
    String? note,
  }) async {
    final res = await api.postJson('/api/shifts', {
      'employeeId': employeeId,
      'templateId': templateId,
      'workDate': toIsoDate(workDate),
      if (note != null) 'note': note,
    });
    return ApiShiftModel.fromJson(res is Map<String, dynamic> ? res : const {});
  }

  /// `status` chỉ nhận "đang làm" | "đã hủy"; backend chặn sửa ca đã tới giờ
  /// hoặc đã có chấm công.
  Future<void> updateShift(
    String id, {
    String? employeeId,
    String? templateId,
    String? workDate,
    String? note,
    String? status,
  }) async {
    await api.putJson('/api/shifts/$id', {
      if (employeeId != null) 'employeeId': employeeId,
      if (templateId != null) 'templateId': templateId,
      if (workDate != null) 'workDate': toIsoDate(workDate),
      if (note != null) 'note': note,
      if (status != null) 'status': status,
    });
  }

  Future<void> deleteShift(String id) async {
    await api.delete('/api/shifts/$id');
  }

  Future<void> assignShift(String id, {required String employeeId}) async {
    await api.postJson('/api/shifts/$id/assign', {'employeeId': employeeId});
  }

  /// Nguyện vọng theo ngày: backend lưu `shiftRegistrations` với
  /// employeeId + templateId + registerDate.
  Future<void> registerShift({
    required String employeeId,
    required String templateId,
    required String registerDate,
  }) async {
    await api.postJson('/api/shifts/register', {
      'employeeId': employeeId,
      'templateId': templateId,
      'registerDate': toIsoDate(registerDate),
    });
  }

  /// Hủy nguyện vọng là DELETE theo id đăng ký; không có endpoint
  /// POST /api/shifts/unregister.
  Future<void> deleteRegistration(String id) async {
    await api.delete('/api/shifts/registrations/$id');
  }

  /// `registerDate` YYYY-MM-DD; lọc chi nhánh dùng `branchId`.
  Future<List<Map<String, dynamic>>> getRegistrations({
    String? employeeId,
    String? branchId,
    String? registerDate,
  }) async {
    final query = <String, String>{};
    if (employeeId != null && employeeId.isNotEmpty) query['employeeId'] = employeeId;
    if (branchId != null && branchId.isNotEmpty) query['branchId'] = branchId;
    if (registerDate != null && registerDate.isNotEmpty) {
      query['registerDate'] = toIsoDate(registerDate);
    }
    final data = await api.getJson('/api/shifts/registrations', query: query);
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final data = await api.getJson('/api/shift-templates');
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    final res = await api.postJson('/api/shift-templates', payload);
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/shift-templates/$id', payload);
  }

  Future<void> deleteTemplate(String id) async {
    await api.delete('/api/shift-templates/$id');
  }
}
