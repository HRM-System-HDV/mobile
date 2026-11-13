import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
import '../../core/utils/date_format.dart';
import 'shift_repository.dart';

class ShiftDetail {
  final String id;
  final String shiftName;
  final String startTime;
  final String endTime;
  final double? hours;
  /// Tên chi nhánh để hiển thị.
  final String branch;
  /// UUID chi nhánh (branchId) để gửi lên API; ca không mang chi nhánh nên
  /// rỗng khi người dùng xem "Tất cả chi nhánh".
  final String branchId;
  final String role;

  /// not_started | working | completed | missed_checkin | missed_checkout | cancelled
  final String attendanceState;

  /// Backend quyết định cửa sổ check-out; UI chỉ cho ra ca khi cờ này bật.
  final bool canCheckout;

  /// 'completed', 'active', 'upcoming', 'missed', 'cancelled'
  final String status;

  const ShiftDetail({
    this.id = '',
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.branch,
    this.branchId = '',
    required this.role,
    this.attendanceState = 'not_started',
    this.canCheckout = false,
    required this.status,
  });

  String get timeRange =>
      (startTime.isEmpty || endTime.isEmpty) ? '—' : '$startTime - $endTime';

  Color get statusColor => ScheduleService.getStatusColor(status);
  String get statusLabel => ScheduleService.getStatusLabel(status);

  ShiftDetail copyWith({
    String? id,
    String? shiftName,
    String? startTime,
    String? endTime,
    double? hours,
    String? branch,
    String? branchId,
    String? role,
    String? attendanceState,
    bool? canCheckout,
    String? status,
  }) {
    return ShiftDetail(
      id: id ?? this.id,
      shiftName: shiftName ?? this.shiftName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hours: hours ?? this.hours,
      branch: branch ?? this.branch,
      branchId: branchId ?? this.branchId,
      role: role ?? this.role,
      attendanceState: attendanceState ?? this.attendanceState,
      canCheckout: canCheckout ?? this.canCheckout,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftDetail &&
          runtimeType == other.runtimeType &&
          shiftName == other.shiftName &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => shiftName.hashCode ^ startTime.hashCode ^ endTime.hashCode;
}

class DayScheduleModel {
  final String dayOfWeek;
  final String date;
  final bool isToday;
  final List<ShiftDetail> shifts;

  const DayScheduleModel({
    required this.dayOfWeek,
    required this.date,
    required this.shifts,
    this.isToday = false,
  });

  bool get isOff => shifts.isEmpty;

  /// Nhãn ngắn dd/MM dùng cho ô ngày hẹp trên thanh lịch.
  String get shortDate {
    final d = parseVnDate(date);
    if (d == null) return date;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}

class ScheduleService {
  /// Lấy ngày Thứ Hai của tuần chứa [date].
  static DateTime getMonday(DateTime date) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
  }

  /// Parse chuỗi giờ:phút 'HH:mm' kết hợp với [date].
  static DateTime? parseShiftTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Tính toán trạng thái ca làm việc theo quy tắc:
  /// - Khi ca đó đã được checkin: 'active' (Đang diễn ra)
  /// - Khi đã checkout / hoàn thành: 'completed' (Đã hoàn thành)
  /// - Khi chưa đến giờ bắt đầu: 'upcoming' (Chưa đến giờ)
  /// - Khi đã qua giờ bắt đầu / ngày trong quá khứ mà chưa chấm công: 'missed' (Quên chấm công)
  static String calculateShiftStatus({
    required DateTime date,
    required String startTime,
    required String endTime,
    bool isCheckedIn = false,
    bool isCheckedOut = false,
  }) {
    if (isCheckedOut) return 'completed';
    if (isCheckedIn) return 'active';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    // Ngày trong tương lai -> Chưa đến giờ
    if (targetDate.isAfter(today)) {
      return 'upcoming';
    }

    // Ngày trong quá khứ mà chưa chấm công -> Quên chấm công
    if (targetDate.isBefore(today)) {
      return 'missed';
    }

    // Ngày hôm nay:
    final startDt = parseShiftTime(today, startTime);
    if (startDt != null && now.isBefore(startDt)) {
      return 'upcoming'; // Chưa đến giờ
    }

    // Đã qua giờ bắt đầu hôm nay mà chưa chấm công -> Quên chấm công
    return 'missed';
  }

  /// Lấy màu sắc biểu thị trạng thái
  static Color getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.primary; // Đang diễn ra
      case 'completed':
        return AppColors.success; // Đã hoàn thành
      case 'missed':
        return AppColors.error; // Quên chấm công (Đỏ)
      case 'cancelled':
        return AppColors.textSecondary; // Ca đã hủy (Xám)
      case 'upcoming':
      default:
        return AppColors.infoBlue; // Chưa đến giờ (Xanh dương)
    }
  }

  /// Lấy nhãn chữ biểu thị trạng thái
  static String getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Đang diễn ra';
      case 'completed':
        return 'Đã hoàn thành';
      case 'missed':
        return 'Quên chấm công';
      case 'cancelled':
        return 'Đã hủy';
      case 'upcoming':
      default:
        return 'Chưa đến giờ';
    }
  }

  /// Trạng thái hiển thị suy ra trực tiếp từ `attendanceState` mà backend tính
  /// (cửa sổ check-out, grace period đã nằm trong đó), không tự đoán từ đồng hồ.
  static String statusFromAttendance(ApiShiftModel shift) {
    if (shift.isCancelled) return 'cancelled';
    switch (shift.attendanceState) {
      case 'completed':
        return 'completed';
      case 'working':
      case 'missed_checkout':
        return 'active';
      case 'missed_checkin':
        return 'missed';
      case 'not_started':
        return 'upcoming';
      default:
        return calculateShiftStatus(
          date: parseVnDate(shift.workDate) ?? DateTime.now(),
          startTime: shift.scheduledStart,
          endTime: shift.scheduledEnd,
          isCheckedIn: shift.checkIn != null,
          isCheckedOut: shift.checkOut != null,
        );
    }
  }

  static bool _matchesDate(String dateStr, DateTime target) {
    // Đọc được mọi định dạng (DD/MM/YYYY, ISO yyyy-MM-dd, dd-MM-yyyy, kèm giờ).
    final d = parseVnDate(dateStr);
    if (d != null) {
      return d.year == target.year && d.month == target.month && d.day == target.day;
    }
    // Dữ liệu cũ chỉ có dd/MM: so khớp ngày/tháng, bỏ qua năm.
    final legacy = RegExp(r'^(\d{1,2})[/-](\d{1,2})$').firstMatch(dateStr.trim());
    if (legacy != null) {
      return int.tryParse(legacy.group(1)!) == target.day &&
          int.tryParse(legacy.group(2)!) == target.month;
    }
    return false;
  }

  static double? _calculateHours(String start, String end) {
    try {
      final sParts = start.split(':').map(int.parse).toList();
      final eParts = end.split(':').map(int.parse).toList();
      final sMin = sParts[0] * 60 + sParts[1];
      final eMin = eParts[0] * 60 + eParts[1];
      final diff = eMin >= sMin ? eMin - sMin : (eMin + 24 * 60) - sMin;
      return double.parse((diff / 60.0).toStringAsFixed(1));
    } catch (_) {
      // Không parse được giờ thì trả null để UI hiện '—', không bịa số giờ.
      return null;
    }
  }

  /// Dựng khung tuần rỗng (7 ngày, mỗi ngày danh sách ca rỗng)
  /// khi API không trả về ca nào. UI đã có empty-state riêng.
  static List<DayScheduleModel> emptyWeek(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = getMonday(today).add(Duration(days: offset * 7));
    const dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    return List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final isToday = dayDate.year == today.year && dayDate.month == today.month && dayDate.day == today.day;
      final dateStr = vnDate(dayDate);
      return DayScheduleModel(
        dayOfWeek: dayNames[i],
        date: dateStr,
        isToday: isToday,
        shifts: const [],
      );
    });
  }

  /// Lấy toàn bộ lịch 7 ngày trong tuần có tích hợp ca thật từ [apiShifts].
  /// Chỉ dùng API thật: khi API rỗng thì trả về khung tuần rỗng, không fallback mock.
  ///
  /// Backend chỉ gửi `templateId` (UUID) trên ca, tên ca lấy từ
  /// `GET /api/shift-templates` qua [templateNames].
  static List<DayScheduleModel> getWeekDataWithApi({
    required int offset,
    required List<ApiShiftModel> apiShifts,
    UserModel? user,
    String? branchName,
    Map<String, String> templateNames = const {},
    ShiftDetail? activeCheckedInShift,
    Set<String>? completedShiftIds,
  }) {
    if (apiShifts.isEmpty) {
      return emptyWeek(offset);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = getMonday(today).add(Duration(days: offset * 7));
    final List<String> dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

    return List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final isToday = dayDate.year == today.year && dayDate.month == today.month && dayDate.day == today.day;
      final dateStr = vnDate(dayDate);

      final matchingShifts = apiShifts.where((s) {
      if (!_matchesDate(s.workDate, dayDate)) return false;
      if (user != null && s.employeeId != null && s.employeeId!.isNotEmpty) {
        if (s.employeeId != user.employeeId) return false;
      }
      return true;
    }).toList();

      List<ShiftDetail> shifts;
      if (matchingShifts.isNotEmpty) {
        shifts = matchingShifts.map((s) {
          final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
          var status = statusFromAttendance(s);
          // Ca đã check-in nhưng người dùng vừa bấm vào ca (hoặc ca đã chốt trong
          // phiên này) thì giữ phản hồi tức thì của UI.
          if (status == 'upcoming' &&
              activeCheckedInShift != null &&
              (activeCheckedInShift.id == s.id ||
                  activeCheckedInShift.shiftName == (templateNames[s.templateId] ?? s.templateId))) {
            status = 'active';
          }
          if (status != 'completed' && completedShiftIds != null && completedShiftIds.contains(s.id)) {
            status = 'completed';
          }

          return ShiftDetail(
            id: s.id,
            shiftName: templateNames[s.templateId] ?? s.templateId,
            startTime: s.scheduledStart,
            endTime: s.scheduledEnd,
            hours: hours,
            branch: branchName ?? '',
            branchId: s.branchId ?? '',
            role: s.note ?? '',
            attendanceState: s.attendanceState,
            canCheckout: s.canCheckout,
            status: status,
          );
        }).toList();
      } else {
        shifts = [];
      }

      return DayScheduleModel(
        dayOfWeek: dayNames[i],
        date: dateStr,
        isToday: isToday,
        shifts: shifts,
      );
    });
  }

  static List<ShiftDetail> getTodayAssignedShiftsWithApi({
    required List<ApiShiftModel> apiShifts,
    UserModel? user,
    String? branchName,
    Map<String, String> templateNames = const {},
    ShiftDetail? activeCheckedInShift,
  }) {
    // Chỉ dùng API thật: khi API rỗng thì trả về danh sách rỗng, không fallback mock.
    if (apiShifts.isEmpty) {
      return [];
    }
    final matchingShifts = apiShifts.where((s) {
      if (!_matchesDate(s.workDate, _today())) return false;
      if (user != null && s.employeeId != null && s.employeeId!.isNotEmpty) {
        if (s.employeeId != user.employeeId) return false;
      }
      return true;
    }).toList();
    if (matchingShifts.isEmpty) return [];
    return matchingShifts.map((s) {
      final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
      return ShiftDetail(
        id: s.id,
        shiftName: templateNames[s.templateId] ?? s.templateId,
        startTime: s.scheduledStart,
        endTime: s.scheduledEnd,
        hours: hours,
        branch: branchName ?? '',
        branchId: s.branchId ?? '',
        role: s.note ?? '',
        attendanceState: s.attendanceState,
        canCheckout: s.canCheckout,
        status: statusFromAttendance(s),
      );
    }).toList();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
