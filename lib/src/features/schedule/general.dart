import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/widgets/week_strip.dart';
import '../../core/utils/date_format.dart';
import '../attendance/attendance_repository.dart';
import 'shift_repository.dart';
import '../profile/employee_repository.dart';

class StaffInShift {
  final String id;
  final String name;
  final String role;
  final String avatarUrl;
  final String checkInStatus; // 'checked_in', 'in_progress', 'not_yet'
  final String checkInTime;
  final String checkOutTime;
  final String phone;

  const StaffInShift({
    this.id = '',
    required this.name,
    required this.role,
    this.avatarUrl = '',
    required this.checkInStatus,
    required this.checkInTime,
    this.checkOutTime = '',
    required this.phone,
  });
}

class GeneralShiftModel {
  final String id;
  final String shiftName;
  final String startTime;
  final String endTime;
  final String status; // 'active', 'upcoming', 'completed'
  final List<StaffInShift> staffList;

  const GeneralShiftModel({
    required this.id,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.staffList,
  });

  String get timeRange =>
      (startTime.isEmpty || endTime.isEmpty) ? '—' : '$startTime - $endTime';
  int get staffCount => staffList.length;
}

class GeneralDayModel {
  final String dayOfWeek;
  final String date;
  final bool isToday;
  final List<GeneralShiftModel> shifts;

  const GeneralDayModel({
    required this.dayOfWeek,
    required this.date,
    required this.shifts,
    this.isToday = false,
  });
}

class GeneralScheduleScreen extends StatefulWidget {
  const GeneralScheduleScreen({super.key});

  @override
  State<GeneralScheduleScreen> createState() => _GeneralScheduleScreenState();
}

class _GeneralScheduleScreenState extends State<GeneralScheduleScreen> {
  final ShiftRepository _shiftRepo = ShiftRepository();
  final EmployeeRepository _empRepo = EmployeeRepository();
  final AttendanceRepository _attRepo = AttendanceRepository();
  List<ApiShiftModel> _apiShifts = [];
  List<Map<String, dynamic>> _apiEmployees = [];
  List<Map<String, dynamic>> _apiTemplates = [];
  int _gracePeriodMinutes = 5;
  String? _loadedBranchSlug;
  String? _loadError;

  // Offset tuần so với tuần hiện tại (0: Tuần này, -1: Tuần trước, 1: Tuần sau, -2, 2, ...)
  int _weekOffset = 0;
  int _selectedDayIndex = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _thisWeekMonday => _getMonday(_today);

  // Set các ID ca đang được mở rộng xổ xuống
  final Set<String> _expandedShiftIds = {'shift_0', 'shift_1', 'shift_2'};

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (_today.weekday - 1).clamp(0, 6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final branch = BranchScope.selectedBranch(context);
    if (_loadedBranchSlug != branch?.slug) {
      _loadedBranchSlug = branch?.slug;
      _loadGeneralData();
    }
  }

  Future<void> _loadGeneralData() async {
    final branch = BranchScope.read(context)?.notifier?.value;
    try {
      final results = await Future.wait([
        _empRepo.getEmployees(),
        _shiftRepo.getShifts(branchSlug: branch?.slug),
        _shiftRepo.getTemplates(),
        _attRepo.getConfig(),
      ]);
      if (!mounted) return;
      final cfg = results[3] as Map<String, dynamic>;
      final grace = cfg['gracePeriodMinutes'];
      setState(() {
        _apiEmployees = (results[0] as List).cast<Map<String, dynamic>>();
        _apiShifts = (results[1] as List).cast<ApiShiftModel>();
        _apiTemplates = (results[2] as List).cast<Map<String, dynamic>>();
        if (grace is int) _gracePeriodMinutes = grace;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Giữ dữ liệu lần trước và báo lỗi, không âm thầm hiện lịch trống.
      setState(() => _loadError =
          e is ApiException ? e.message : 'Không tải được lịch làm việc');
    }
  }

  bool _matchesDate(String dateStr, DateTime target) {
    if (dateStr.isEmpty) return false;
    // Đọc được mọi định dạng (DD/MM/YYYY, ISO yyyy-MM-dd, dd-MM-yyyy, kèm giờ).
    final d = parseVnDate(dateStr);
    if (d != null) {
      return d.year == target.year && d.month == target.month && d.day == target.day;
    }
    // Dữ liệu cũ chỉ có dd/MM: so ngày/tháng, bỏ qua năm.
    final legacy = RegExp(r'^(\d{1,2})[/-](\d{1,2})$').firstMatch(dateStr.trim());
    if (legacy != null) {
      return int.tryParse(legacy.group(1)!) == target.day &&
          int.tryParse(legacy.group(2)!) == target.month;
    }
    return false;
  }

  DateTime _getMonday(DateTime date) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
  }

  String _getWeekTitle(int offset) {
    if (offset == 0) return 'Tuần này';
    if (offset == -1) return 'Tuần trước';
    if (offset == 1) return 'Tuần sau';
    if (offset < -1) return '${offset.abs()} tuần trước';
    return '$offset tuần sau';
  }

  String _getWeekRange(int offset) {
    final monday = _thisWeekMonday.add(Duration(days: offset * 7));
    final sunday = monday.add(const Duration(days: 6));
    return '${vnDate(monday)} - ${vnDate(sunday)}';
  }

  String _calcShiftStatus(DateTime dayDate, String startTime, String endTime) {
    final today = DateTime(_today.year, _today.month, _today.day);
    final target = DateTime(dayDate.year, dayDate.month, dayDate.day);
    if (target.isBefore(today)) return 'completed';
    if (target.isAfter(today)) return 'upcoming';

    if (startTime.isEmpty || endTime.isEmpty) return 'upcoming';

    int toMinutes(String timeStr) {
      final parts = (timeStr.isEmpty ? '00:00' : timeStr).split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return h * 60 + m;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMin = toMinutes(startTime);
    var endMin = toMinutes(endTime);
    if (endMin <= startMin) endMin += 1440;

    if (nowMinutes >= endMin) return 'completed';
    if (nowMinutes < startMin) return 'upcoming';
    return 'in_progress';
  }

  bool _matchesShiftTemplate(String val, String templateName, String templateId) {
    if (val.isEmpty || val == 'Nghỉ' || val == 'off') return false;
    final cleanVal = val.trim().toLowerCase();
    final cleanTName = templateName.trim().toLowerCase();
    final cleanTId = templateId.trim().toLowerCase();

    if (cleanVal == 't1' || cleanVal == 'st-1') return cleanTName.contains('sáng');
    if (cleanVal == 't2' || cleanVal == 'st-2') return cleanTName.contains('chiều');
    if (cleanVal == 't3' || cleanVal == 'st-3') return cleanTName.contains('tối');
    if (cleanVal == 't4' || cleanVal == 'st-4') return cleanTName.contains('hành chính');

    return cleanVal == cleanTName ||
        cleanVal == cleanTId ||
        cleanVal.contains(cleanTName) ||
        cleanTName.contains(cleanVal);
  }

  List<GeneralDayModel> _getGeneralWeekData(int offset) {
    final monday = _thisWeekMonday.add(Duration(days: offset * 7));
    final List<String> dayShortNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final isToday = dayDate.year == _today.year && dayDate.month == _today.month && dayDate.day == _today.day;
      final isPast = dayDate.isBefore(_today);
      final dateStr = vnDate(dayDate);

      final shiftsForDay = _apiShifts.where((s) => _matchesDate(s.date, dayDate)).toList();
      final dayShifts = <GeneralShiftModel>[];

      // Dựng danh sách ca theo 3 khung ca mẫu chuẩn từ Backend (Ca Sáng, Ca Chiều, Ca Tối)
      // giống hệt như trên Web ScheduleOverview
      if (_apiTemplates.isNotEmpty) {
        for (int ti = 0; ti < _apiTemplates.length; ti++) {
          final t = _apiTemplates[ti];
          final tId = t['id']?.toString() ?? 't_$ti';
          final tName = t['name']?.toString() ?? 'Ca làm việc';
          final tStart = t['startTime']?.toString() ?? '';
          final tEnd = t['endTime']?.toString() ?? '';

          final staffList = <StaffInShift>[];
          final addedEmpIds = <String>{};

          for (final s in shiftsForDay) {
            final shiftTName = s.template;
            if (_matchesShiftTemplate(shiftTName, tName, tId)) {
              final empId = s.employeeId ?? '';
              if (empId.isNotEmpty && !addedEmpIds.contains(empId)) {
                addedEmpIds.add(empId);
                final emp = _apiEmployees.firstWhere(
                  (e) => (e['id']?.toString() == empId || e['email']?.toString() == empId || e['employeeCode']?.toString() == empId),
                  orElse: () => <String, dynamic>{'name': empId, 'role': 'Nhân viên'},
                );
                final hasCheckedIn = s.checkIn != null && s.checkIn!.isNotEmpty && s.checkIn != '—';
                staffList.add(StaffInShift(
                  id: emp['id']?.toString() ?? empId,
                  name: emp['name']?.toString() ?? 'Nhân viên',
                  role: emp['role']?.toString() ?? (emp['position']?.toString() ?? 'Nhân viên'),
                  checkInStatus: hasCheckedIn ? 'checked_in' : 'not_yet',
                  // Chưa chấm công thì không mượn giờ bắt đầu ca làm giờ chấm công.
                  checkInTime: hasCheckedIn ? s.checkIn! : '',
                  checkOutTime: (s.checkOut != null && s.checkOut!.isNotEmpty && s.checkOut != '—') ? s.checkOut! : '',
                  phone: emp['phone']?.toString() ?? '—',
                ));
              }
            }
          }

          dayShifts.add(GeneralShiftModel(
            id: tId,
            shiftName: tName,
            startTime: tStart,
            endTime: tEnd,
            status: _calcShiftStatus(dayDate, tStart, tEnd),
            staffList: staffList,
          ));
        }
      } else {
        // Fallback nếu API templates chưa về
        final Map<String, List<ApiShiftModel>> grouped = {};
        for (final s in shiftsForDay) {
          final key = '${s.scheduledStart}-${s.scheduledEnd}-${s.template}';
          grouped.putIfAbsent(key, () => []).add(s);
        }
        for (final entry in grouped.entries) {
          final first = entry.value.first;
          final staffList = <StaffInShift>[];
          for (final s in entry.value) {
            if (s.employeeId != null && s.employeeId!.isNotEmpty) {
              final emp = _apiEmployees.firstWhere(
                (e) => (e['id']?.toString() == s.employeeId || e['email']?.toString() == s.employeeId || e['employeeCode']?.toString() == s.employeeId),
                orElse: () => <String, dynamic>{'name': s.employeeId, 'role': 'Nhân viên'},
              );
              final hasCheckedIn = s.checkIn != null && s.checkIn!.isNotEmpty && s.checkIn != '—';
              staffList.add(StaffInShift(
                id: emp['id']?.toString() ?? (s.employeeId ?? ''),
                name: emp['name']?.toString() ?? 'Nhân viên',
                role: emp['role']?.toString() ?? (emp['position']?.toString() ?? 'Nhân viên'),
                checkInStatus: hasCheckedIn ? 'checked_in' : 'not_yet',
                checkInTime: hasCheckedIn ? s.checkIn! : '',
                checkOutTime: (s.checkOut != null && s.checkOut!.isNotEmpty && s.checkOut != '—') ? s.checkOut! : '',
                phone: emp['phone']?.toString() ?? '—',
              ));
            }
          }
          dayShifts.add(GeneralShiftModel(
            id: first.id,
            shiftName: first.template,
            startTime: first.scheduledStart,
            endTime: first.scheduledEnd,
            status: isPast ? 'completed' : (isToday ? 'in_progress' : 'upcoming'),
            staffList: staffList,
          ));
        }
      }

      return GeneralDayModel(
        dayOfWeek: dayShortNames[i],
        date: dateStr,
        isToday: isToday,
        shifts: dayShifts,
      );
    });
  }

  void _changeWeek(int newOffset) {
    setState(() {
      _weekOffset = newOffset;
      if (_weekOffset == 0) {
        _selectedDayIndex = (_today.weekday - 1).clamp(0, 6);
      } else {
        _selectedDayIndex = 0; // Mặc định Thứ 2 cho các tuần khác
      }
    });
  }

  void _toggleShiftExpand(String shiftId) {
    setState(() {
      if (_expandedShiftIds.contains(shiftId)) {
        _expandedShiftIds.remove(shiftId);
      } else {
        _expandedShiftIds.add(shiftId);
      }
    });
  }

  void _callStaff(StaffInShift staff) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📞 Đang kết nối cuộc gọi tới ${staff.name} (${staff.phone})...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getGeneralWeekData(_weekOffset);
    final selectedDay = (_selectedDayIndex >= 0 && _selectedDayIndex < weekDays.length)
        ? weekDays[_selectedDayIndex]
        : (weekDays.isNotEmpty ? weekDays.first : const GeneralDayModel(dayOfWeek: '', date: '', shifts: []));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch làm việc chung'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          BranchSelector(includeAll: true),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh chọn ngày trong tuần (WeekDayStrip tái sử dụng)
          WeekDayStrip(
            weekLabel: '${_getWeekTitle(_weekOffset)}  •  ${_getWeekRange(_weekOffset)}',
            days: List.generate(weekDays.length, (index) {
              final day = weekDays[index];
              return {
                'label': day.dayOfWeek,
                'day': parseVnDate(day.date)?.day ?? 0,
                'isToday': day.isToday,
                'dotColor': day.isToday ? AppColors.primary : Colors.grey.shade300,
              };
            }),
            selectedIndex: _selectedDayIndex,
            onDaySelected: (index) => setState(() => _selectedDayIndex = index),
            onPrevWeek: () => _changeWeek(_weekOffset - 1),
            onNextWeek: () => _changeWeek(_weekOffset + 1),
          ),
          const Divider(height: 1),

          // 2. Tiêu đề ngày được chọn & danh sách ca làm
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGeneralData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                if (_loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.triangleExclamation, size: 16, color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _loadError!,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${selectedDay.dayOfWeek}, Ngày ${toVnDate(selectedDay.date)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (selectedDay.isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Hôm nay',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${selectedDay.shifts.length} ca làm',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chạm vào từng ca để xem danh sách nhân viên phân công',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // Empty state if no shifts
                if (selectedDay.shifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      children: [
                        FaIcon(FontAwesomeIcons.calendarXmark, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Không có ca làm việc nào',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ngày này chưa có ca làm hoặc chưa được phân công nhân sự.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // 3. Danh sách các ca làm việc (Accordion xổ xuống nhân viên)
                ...selectedDay.shifts.map((shift) {
                  final isExpanded = _expandedShiftIds.contains(shift.id);
                  return _buildGeneralShiftAccordion(shift, isExpanded, selectedDay);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralShiftAccordion(GeneralShiftModel shift, bool isExpanded, GeneralDayModel day) {
    Color statusColor;
    String statusText;
    if (shift.status == 'completed') {
      statusColor = AppColors.success;
      statusText = 'Đã hoàn thành';
    } else if (shift.status == 'active' || shift.status == 'in_progress') {
      statusColor = Colors.blue;
      statusText = 'Đang diễn ra';
    } else {
      statusColor = Colors.grey;
      statusText = 'Sắp diễn ra';
    }

    final Color cardBorderColor = isExpanded ? AppColors.primary.withValues(alpha: 0.45) : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Ca làm (Clickable để xổ xuống danh sách nhân viên)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleShiftExpand(shift.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const FaIcon(FontAwesomeIcons.clock, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Tên ca & Khung giờ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.shiftName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.clock, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                shift.timeRange,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Badge số nhân viên
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.userGroup, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${shift.staffCount} NV',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mũi tên xổ xuống
                  FaIcon(
                    isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    color: isExpanded ? AppColors.primary : Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Phần xổ xuống: Danh sách các nhân viên trong ca
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: shift.staffList.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Trống',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, top: 2, bottom: 8),
                          child: Text(
                            'Nhân viên trong ca (${shift.staffCount} người):',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        ),
                        ...shift.staffList.asMap().entries.map((entry) {
                          final staff = entry.value;
                          return _buildStaffItemTile(staff, shift, day);
                        }),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffItemTile(StaffInShift staff, GeneralShiftModel shift, GeneralDayModel day) {
    // Quên chấm công: Chưa chấm công mà ngày đã qua, HOẶC hôm nay đã qua giờ bắt đầu ca
    final isForgot = staff.checkInStatus == 'not_yet' && (() {
      if (shift.status == 'completed') return true;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final parsedDay = parseVnDate(day.date);
      if (parsedDay == null) return false;
      final dayDate = DateTime(parsedDay.year, parsedDay.month, parsedDay.day);
      if (dayDate.isBefore(today)) return true;
      if (dayDate.isAfter(today)) return false;

      // Hôm nay: kiểm tra đã qua giờ bắt đầu ca chưa
      final startStr = shift.timeRange.split('-')[0].trim();
      final partsStart = startStr.split(':');
      if (partsStart.length < 2) return false;
      final sh = int.tryParse(partsStart[0]) ?? 0;
      final sm = int.tryParse(partsStart[1]) ?? 0;
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = sh * 60 + sm;
      return nowMinutes >= startMinutes;
    })();

    bool isLate = false;
    if (staff.checkInStatus == 'checked_in') {
      final startStr = shift.timeRange.split('-')[0].trim();
      final partsStart = startStr.split(':');
      final partsCheck = staff.checkInTime.split(':');
      if (partsStart.length == 2 && partsCheck.length == 2) {
        final sh = int.tryParse(partsStart[0]) ?? 0;
        final sm = int.tryParse(partsStart[1]) ?? 0;
        final ch = int.tryParse(partsCheck[0]) ?? 0;
        final cm = int.tryParse(partsCheck[1]) ?? 0;
        isLate = ch * 60 + cm - (sh * 60 + sm) > _gracePeriodMinutes;
      }
    }
    Color checkInColor = staff.checkInStatus == 'checked_in'
        ? (isLate ? Colors.orange.shade700 : AppColors.success)
        : (staff.checkInStatus == 'in_progress' ? Colors.orange : (isForgot ? Colors.red : Colors.grey));

    String checkInLabel = staff.checkInStatus == 'checked_in'
        ? (isLate ? 'Trễ' : 'Đúng giờ')
        : (staff.checkInStatus == 'in_progress' ? 'Đang trong ca' : (isForgot ? 'Quên chấm công' : 'Chưa chấm công'));

    // Phân quyền xem chi tiết ca:
    // - Admin hoặc Manager: xem chi tiết ca của mọi nhân viên.
    // - Nhân viên: chỉ được xem chi tiết ca của chính mình, KHÔNG được xem ca của người khác.
    final currentUser = UserScope.currentUser(context);
    final bool canManage = UserScope.canManage(context);
    final bool isOwnShift = currentUser != null &&
        currentUser.name.trim().toLowerCase() == staff.name.trim().toLowerCase();
    final bool canViewDetail = canManage || isOwnShift;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: canViewDetail
            ? () => _showStaffShiftDetail(staff, shift, day)
            : () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        FaIcon(FontAwesomeIcons.lock, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chỉ Quản trị viên và Quản lý mới có quyền xem chi tiết ca của nhân viên khác.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.textDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  staff.name.split(' ').last.substring(0, 1),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),

              // Tên & Vị trí
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            staff.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwnShift) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tôi',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff.role,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Trạng thái điểm danh & Nút gọi
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: checkInColor),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            checkInLabel,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: checkInColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _callStaff(staff),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(FontAwesomeIcons.phone, size: 12, color: AppColors.primary),
                              SizedBox(width: 3),
                              Text('Gọi', style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  if (canViewDetail)
                    const FaIcon(FontAwesomeIcons.chevronRight, size: 18, color: AppColors.textSecondary)
                  else
                    FaIcon(FontAwesomeIcons.lock, size: 15, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffShiftDetail(StaffInShift staff, GeneralShiftModel shift, GeneralDayModel day) {
    final currentUser = UserScope.currentUser(context);
    final bool canManage = UserScope.canManage(context);
    final bool isOwnShift = currentUser != null &&
        currentUser.name.trim().toLowerCase() == staff.name.trim().toLowerCase();

    if (!canManage && !isOwnShift) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              FaIcon(FontAwesomeIcons.lock, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chỉ Quản trị viên và Quản lý mới có quyền xem chi tiết ca của nhân viên khác.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    context.push('/schedule/staff-detail', extra: {
      'staff': staff,
      'shift': shift,
      'day': day,
      'gracePeriodMinutes': _gracePeriodMinutes,
    });
  }
}
