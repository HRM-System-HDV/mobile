import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
import 'shift_repository.dart';

class ShiftDetail {
  final String id;
  final String shiftName;
  final String startTime;
  final String endTime;
  final double hours;
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

  String get timeRange => '$startTime - $endTime';

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
  /// - Khi đã qua giờ bắt đầu mà chưa checkin: 'missed' (Quên chấm công)
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

    // Ngày trong quá khứ mà chưa check-in -> Quên chấm công
    if (targetDate.isBefore(today)) {
      return 'missed';
    }

    // Ngày trong tương lai -> Chưa đến giờ
    if (targetDate.isAfter(today)) {
      return 'upcoming';
    }

    // Ngày hôm nay:
    final startDt = parseShiftTime(today, startTime);
    if (startDt != null) {
      if (now.isBefore(startDt)) {
        return 'upcoming'; // Chưa đến giờ
      } else {
        return 'missed'; // Đã qua giờ bắt đầu mà chưa check-in -> Quên chấm công
      }
    }

    return 'upcoming';
  }

  /// Lấy màu sắc biểu thị trạng thái
  static Color getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.primary; // Đang diễn ra
      case 'completed':
        return AppColors.success; // Đã hoàn thành
      case 'missed':
        return const Color(0xFFDC2626); // Quên chấm công (Đỏ)
      case 'upcoming':
      default:
        return const Color(0xFF2563EB); // Chưa đến giờ (Xanh dương)
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

  static ShiftDetail _createShift({
    required String id,
    required String shiftName,
    required String startTime,
    required String endTime,
    required double hours,
    required String branch,
    required String role,
    required DateTime date,
    ShiftDetail? activeCheckedInShift,
    Set<String>? completedShiftIds,
  }) {
    final bool isCheckedIn = activeCheckedInShift != null &&
        (activeCheckedInShift.id == id ||
            (activeCheckedInShift.shiftName == shiftName && activeCheckedInShift.startTime == startTime));
    final bool isCheckedOut = completedShiftIds != null && completedShiftIds.contains(id);

    final status = calculateShiftStatus(
      date: date,
      startTime: startTime,
      endTime: endTime,
      isCheckedIn: isCheckedIn,
      isCheckedOut: isCheckedOut,
    );

    return ShiftDetail(
      id: id,
      shiftName: shiftName,
      startTime: startTime,
      endTime: endTime,
      hours: hours,
      branch: branch,
      role: role,
      status: status,
    );
  }

  /// Lấy danh sách ca làm việc được phân công cho nhân viên theo ngày cụ thể.
  /// Nếu nhân viên không được xếp ca (hoặc ngày nghỉ như Chủ Nhật), trả về danh sách rỗng `[]`.
  static List<ShiftDetail> getAssignedShiftsForDate(
    DateTime date, {
    UserModel? user,
    String? branchName,
    ShiftDetail? activeCheckedInShift,
    Set<String>? completedShiftIds,
  }) {
    final branch = branchName ?? 'Chi nhánh 01';

    // Xác định theo thứ trong tuần (1: Thứ 2, ..., 7: Chủ Nhật)
    final weekday = date.weekday;

    switch (weekday) {
      case DateTime.monday: // Thứ 2
        return [
          _createShift(
            id: 'shift_mon_1',
            shiftName: 'Ca Sáng',
            startTime: '08:00',
            endTime: '12:00',
            hours: 4.0,
            branch: branch,
            role: 'Phục vụ',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.tuesday: // Thứ 3
        return [
          _createShift(
            id: 'shift_tue_1',
            shiftName: 'Ca Chiều',
            startTime: '12:00',
            endTime: '18:00',
            hours: 6.0,
            branch: branch,
            role: 'Phục vụ',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.wednesday: // Thứ 4
        return [
          _createShift(
            id: 'shift_wed_1',
            shiftName: 'Ca Full ngày',
            startTime: '08:00',
            endTime: '16:00',
            hours: 8.0,
            branch: branch,
            role: 'Thu ngân hỗ trợ',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.thursday: // Thứ 5
        return [
          _createShift(
            id: 'shift_thu_1',
            shiftName: 'Ca Sáng (Ca 1)',
            startTime: '08:00',
            endTime: '12:00',
            hours: 4.0,
            branch: branch,
            role: 'Phục vụ chính',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
          _createShift(
            id: 'shift_thu_2',
            shiftName: 'Ca Tối (Ca 2)',
            startTime: '18:00',
            endTime: '22:30',
            hours: 4.5,
            branch: branch,
            role: 'Phục vụ đóng cửa',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.friday: // Thứ 6
        return [
          _createShift(
            id: 'shift_fri_1',
            shiftName: 'Ca Chiều',
            startTime: '12:00',
            endTime: '18:00',
            hours: 6.0,
            branch: branch,
            role: 'Phục vụ',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.saturday: // Thứ 7
        return [
          _createShift(
            id: 'shift_sat_1',
            shiftName: 'Ca Sáng (Cuối tuần)',
            startTime: '07:00',
            endTime: '12:00',
            hours: 5.0,
            branch: branch,
            role: 'Pha chế / Barista',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
          _createShift(
            id: 'shift_sat_2',
            shiftName: 'Ca Tối (Cao điểm)',
            startTime: '18:00',
            endTime: '23:00',
            hours: 5.0,
            branch: branch,
            role: 'Phục vụ bàn',
            date: date,
            activeCheckedInShift: activeCheckedInShift,
            completedShiftIds: completedShiftIds,
          ),
        ];

      case DateTime.sunday: // Chủ Nhật - Không có ca xếp
      default:
        return [];
    }
  }

  /// Lấy danh sách ca làm việc được phân công cho nhân viên trong ngày hôm nay.
  static List<ShiftDetail> getTodayAssignedShifts({
    UserModel? user,
    String? branchName,
    ShiftDetail? activeCheckedInShift,
    Set<String>? completedShiftIds,
  }) {
    return getAssignedShiftsForDate(
      DateTime.now(),
      user: user,
      branchName: branchName,
      activeCheckedInShift: activeCheckedInShift,
      completedShiftIds: completedShiftIds,
    );
  }

  /// Lấy toàn bộ lịch 7 ngày trong tuần theo `weekOffset` (0: tuần này, -1: tuần trước, 1: tuần sau).
  static List<DayScheduleModel> getWeekData(
    int offset, {
    UserModel? user,
    String? branchName,
    ShiftDetail? activeCheckedInShift,
    Set<String>? completedShiftIds,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = getMonday(today).add(Duration(days: offset * 7));
    final List<String> dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

    return List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final isToday = dayDate.year == today.year && dayDate.month == today.month && dayDate.day == today.day;
      final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';
      final shifts = getAssignedShiftsForDate(
        dayDate,
        user: user,
        branchName: branchName,
        activeCheckedInShift: isToday ? activeCheckedInShift : null,
        completedShiftIds: completedShiftIds,
      );

      return DayScheduleModel(
        dayOfWeek: dayNames[i],
        date: dateStr,
        isToday: isToday,
        shifts: shifts,
      );
    });
  }

  static bool _matchesDate(String dateStr, DateTime target) {
    try {
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts[0].length == 4) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          return y == target.year && m == target.month && d == target.day;
        } else {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return y == target.year && m == target.month && d == target.day;
        }
      } else if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts[0].length == 4) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          return y == target.year && m == target.month && d == target.day;
        } else {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return y == target.year && m == target.month && d == target.day;
        }
      }
    } catch (_) {}
    return false;
  }

  static double _calculateHours(String start, String end) {
    try {
      final sParts = start.split(':').map(int.parse).toList();
      final eParts = end.split(':').map(int.parse).toList();
      final sMin = sParts[0] * 60 + sParts[1];
      final eMin = eParts[0] * 60 + eParts[1];
      final diff = eMin >= sMin ? eMin - sMin : (eMin + 24 * 60) - sMin;
      return double.parse((diff / 60.0).toStringAsFixed(1));
    } catch (_) {
      return 5.0;
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
      final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';
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
      final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';

      final matchingShifts = apiShifts.where((s) => _matchesDate(s.date, dayDate)).toList();

      List<ShiftDetail> shifts;
      if (matchingShifts.isNotEmpty) {
        shifts = matchingShifts.map((s) {
          final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
          final isCheckedIn = activeCheckedInShift != null &&
              (activeCheckedInShift.id == s.id || activeCheckedInShift.shiftName == s.template);
          final isCheckedOut = completedShiftIds != null && completedShiftIds.contains(s.id);
          final status = (s.status == 'hoàn thành' || s.status == 'completed')
              ? 'completed'
              : calculateShiftStatus(
                  date: dayDate,
                  startTime: s.scheduledStart,
                  endTime: s.scheduledEnd,
                  isCheckedIn: isCheckedIn,
                  isCheckedOut: isCheckedOut,
                );

          return ShiftDetail(
            id: s.id,
            shiftName: s.template,
            startTime: s.scheduledStart,
            endTime: s.scheduledEnd,
            hours: hours,
            branch: s.branchSlug ?? branchName ?? 'HN-1',
            role: s.note ?? 'Nhân viên trực ca',
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
    final matchingShifts = apiShifts.where((s) => _matchesDate(s.date, today)).toList();
    if (matchingShifts.isEmpty) return [];
    return matchingShifts.map((s) {
      final hours = _calculateHours(s.scheduledStart, s.scheduledEnd);
      return ShiftDetail(
        id: s.id,
        shiftName: s.template,
        startTime: s.scheduledStart,
        endTime: s.scheduledEnd,
        hours: hours,
        branch: s.branchSlug ?? branchName ?? 'HN-1',
        role: s.note ?? 'Nhân viên',
        status: s.status,
      );
    }).toList();
  }
}
