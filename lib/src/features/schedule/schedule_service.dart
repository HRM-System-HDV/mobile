import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/models/user.dart';
import '../../core/utils/date_format.dart';
import 'shift_repository.dart';

class ShiftDetail {
  final String id;
  final String shiftName;
  final String startTime;
  final String endTime;
  final double? hours;
  final String branch;
  final String role;
  final String status; // 'completed', 'active', 'upcoming', 'missed'

  const ShiftDetail({
    this.id = '',
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.branch,
    required this.role,
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
    String? role,
    String? status,
  }) {
    return ShiftDetail(
      id: id ?? this.id,
      shiftName: shiftName ?? this.shiftName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hours: hours ?? this.hours,
      branch: branch ?? this.branch,
      role: role ?? this.role,
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
      case 'upcoming':
      default:
        return 'Chưa đến giờ';
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
  static List<DayScheduleModel> getWeekDataWithApi({
    required int offset,
    required List<ApiShiftModel> apiShifts,
    UserModel? user,
    String? branchName,
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
      if (!_matchesDate(s.date, dayDate)) return false;
      if (user != null && s.employeeId != null && s.employeeId!.isNotEmpty) {
        final matchesId = s.employeeId == user.id;
        final matchesEmail = s.employeeId == user.email;
        if (!matchesId && !matchesEmail) return false;
      }
      return true;
    }).toList();

      List<ShiftDetail> shifts;
      if (matchingShifts.isNotEmpty) {
        shifts = matchingShifts.map((s) {
          final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
          final isCheckedIn = s.checkIn != null ||
              (activeCheckedInShift != null &&
                  (activeCheckedInShift.id == s.id || activeCheckedInShift.shiftName == s.template));
          final isCheckedOut = s.checkOut != null ||
              (completedShiftIds != null && completedShiftIds.contains(s.id));
          // Ưu tiên trạng thái và giờ chấm công thật từ API thay vì suy diễn từ đồng hồ.
          final String status;
          if (s.status == 'hoàn thành' || s.status == 'completed' || isCheckedOut) {
            status = 'completed';
          } else if (s.status == 'missed' || s.status == 'absent') {
            status = 'missed';
          } else {
            status = calculateShiftStatus(
              date: dayDate,
              startTime: s.scheduledStart,
              endTime: s.scheduledEnd,
              isCheckedIn: isCheckedIn,
              isCheckedOut: isCheckedOut,
            );
          }

          final rawBranch = s.branchSlug ?? branchName ?? '';
          final branchDisplayName = rawBranch.isNotEmpty ? branchById(rawBranch).name : '';

          return ShiftDetail(
            id: s.id,
            shiftName: s.template,
            startTime: s.scheduledStart,
            endTime: s.scheduledEnd,
            hours: hours,
            branch: branchDisplayName,
            role: s.note ?? '',
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
    ShiftDetail? activeCheckedInShift,
  }) {
    // Chỉ dùng API thật: khi API rỗng thì trả về danh sách rỗng, không fallback mock.
    if (apiShifts.isEmpty) {
      return [];
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchingShifts = apiShifts.where((s) {
      if (!_matchesDate(s.date, today)) return false;
      if (user != null && s.employeeId != null && s.employeeId!.isNotEmpty) {
        final matchesId = s.employeeId == user.id;
        final matchesEmail = s.employeeId == user.email;
        if (!matchesId && !matchesEmail) return false;
      }
      return true;
    }).toList();
    if (matchingShifts.isEmpty) return [];
    return matchingShifts.map((s) {
      final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
      final String status;
      if (s.status == 'hoàn thành' || s.status == 'completed' || s.checkOut != null) {
        status = 'completed';
      } else if (s.checkIn != null) {
        status = 'active';
      } else if (s.status == 'missed' || s.status == 'absent') {
        status = 'missed';
      } else {
        status = calculateShiftStatus(
          date: today,
          startTime: s.scheduledStart,
          endTime: s.scheduledEnd,
        );
      }
      final rawBranch = s.branchSlug ?? branchName ?? '';
      final branchDisplayName = rawBranch.isNotEmpty ? branchById(rawBranch).name : '';

      return ShiftDetail(
        id: s.id,
        shiftName: s.template,
        startTime: s.scheduledStart,
        endTime: s.scheduledEnd,
        hours: hours,
        branch: branchDisplayName,
        role: s.note ?? '',
        status: status,
      );
    }).toList();
  }
}
