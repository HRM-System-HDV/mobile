import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/widgets/week_strip.dart';
import '../../core/models/user.dart';
import '../../core/utils/date_format.dart';
import 'shift_repository.dart';
import '../profile/employee_repository.dart';

import '../../core/state/branch_scope.dart';

/// Model nhân sự đã được phân công vào ca làm việc
class AssignedStaff {
  final String id;
  final String name;
  final String role;
  final String avatarText;
  bool isRecurring;
  String? shiftId;

  AssignedStaff({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarText,
    this.isRecurring = true,
    this.shiftId,
  });
}

/// Cấu hình ca làm việc chuẩn
class ShiftInfo {
  final String id;
  final String name;
  final String timeRange;
  final FaIconData icon;
  final Color color;

  const ShiftInfo({
    required this.id,
    required this.name,
    required this.timeRange,
    required this.icon,
    required this.color,
  });

  String get startTime => timeRange.split('-')[0].trim();
  String get endTime => timeRange.contains('-') ? timeRange.split('-')[1].trim() : '';
  bool get hasSchedule => timeRange.contains('-') && startTime.isNotEmpty && endTime.isNotEmpty;
}

/// Nguyện vọng đăng ký ca của một nhân sự trong tuần đang xem.
/// DB chỉ lưu employeeId/shiftId/week (week là chuỗi dd/MM), không có thứ hay tên ca.
class EmployeeShiftRegistration {
  final String employeeId;
  final Map<String, String> days;

  const EmployeeShiftRegistration({
    required this.employeeId,
    required this.days,
  });
}

class ShiftAssignmentScreen extends StatefulWidget {
  final UserModel currentUser;

  const ShiftAssignmentScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ShiftAssignmentScreen> createState() => _ShiftAssignmentScreenState();
}

class _ShiftAssignmentScreenState extends State<ShiftAssignmentScreen> {
  // Tuần & ngày đang chọn
  int _weekOffset = 0;
  int _selectedDayIndex = 0;

  // Set các ID ca đang được mở rộng xổ xuống
  final Set<String> _expandedShiftIds = {};

  // Khung ca lấy từ GET /api/shift-templates; không có ca mẫu cứng vì giờ làm
  // cứng sẽ bị gửi ngược lên server khi xếp ca và tính sai công/lương.
  List<ShiftInfo> _availableShifts = [];

  // Danh sách nhân sự của chi nhánh — chỉ dùng API thật, khởi rỗng để hiện empty state
  List<AssignedStaff> _branchEmployees = [];

  // Dữ liệu phân công ca: Map<Thứ (T2..CN), Map<Tên ca, List<Nhân sự>>>
  late Map<String, Map<String, List<AssignedStaff>>> _assignments;

  // Dữ liệu nguyện vọng — chỉ dùng API thật (getRegistrations), rỗng thì hiện empty state
  List<EmployeeShiftRegistration> _registrations = [];

  final List<String> _weekDayKeys = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final List<String> _weekDayFullNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _thisWeekMonday => _getMonday(_today);

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

  String? _loadedBranchSlug;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (_today.weekday - 1).clamp(0, 6);
    _initAssignments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final branch = BranchScope.selectedBranch(context);
    if (_loadedBranchSlug != branch?.slug) {
      _loadedBranchSlug = branch?.slug;
      _loadApiData();
    }
  }

  void _initAssignments() {
    // Khởi rỗng — chỉ điền từ API thật trong _loadApiData, không sinh mẫu cứng.
    _assignments = {
      for (final k in _weekDayKeys)
        k: {
          for (final s in _availableShifts) s.name: <AssignedStaff>[],
        },
    };
  }

  /// Khóa ngắn dd/MM (chỉ dùng để so khớp đăng ký ca cũ; ngày gửi API là DD/MM/YYYY).
  String _ddMM(DateTime d) => vnDate(d).substring(0, 5);

  /// Đọc ngày ca từ API (DD/MM/YYYY, ISO hoặc dd-MM-yyyy cũ) về DateTime.
  DateTime? _parseShiftDate(String raw) => parseVnDate(raw);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text('❌ $message'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Không kết nối được máy chủ, vui lòng thử lại.';

  Future<void> _loadApiData() async {
    final branch = BranchScope.read(context)?.notifier?.value;
    try {
      // 1. Khung ca mẫu — nguồn duy nhất cho tên ca và giờ làm.
      final rawTemplates = await ShiftRepository().getTemplates();
      final templates = <ShiftInfo>[];
      for (final t in rawTemplates) {
        final id = t['id']?.toString() ?? '';
        final name = t['name']?.toString() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final start = t['startTime']?.toString() ?? '';
        final end = t['endTime']?.toString() ?? '';

        FaIconData icon = FontAwesomeIcons.briefcase;
        Color color = const Color(0xFF00695C);
        if (name.contains('Sáng')) {
          icon = FontAwesomeIcons.sun;
          color = const Color(0xFFE65100);
        } else if (name.contains('Chiều')) {
          icon = FontAwesomeIcons.cloudSun;
          color = const Color(0xFF0277BD);
        } else if (name.contains('Tối')) {
          icon = FontAwesomeIcons.moon;
          color = const Color(0xFF4A148C);
        }

        templates.add(ShiftInfo(
          id: id,
          name: name,
          timeRange: (start.isEmpty || end.isEmpty) ? '—' : '$start - $end',
          icon: icon,
          color: color,
        ));
      }

      // 2. Nhân sự của chi nhánh.
      final employees = await EmployeeRepository().getEmployees(branchSlug: branch?.slug);
      final staff = <AssignedStaff>[];
      for (final e in employees) {
        final id = e['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final name = e['name']?.toString() ?? '';
        final avatar = name
            .trim()
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map((s) => s[0])
            .take(2)
            .join()
            .toUpperCase();
        staff.add(AssignedStaff(
          id: id,
          name: name.isEmpty ? '—' : name,
          role: e['role']?.toString() ?? '',
          avatarText: avatar.isEmpty ? '—' : avatar,
        ));
      }

      // 3. Nguyện vọng: DB chỉ có employeeId/shiftId/week, week là chuỗi dd/MM
      // của ngày đăng ký. Phải quy đổi sang thứ và tên ca, không đoán mặc định.
      final rawRegs = await ShiftRepository().getRegistrations(branchSlug: branch?.slug);
      final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));
      final dayKeyByDate = <String, String>{};
      for (var i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        // Khóa mới DD/MM/YYYY; giữ thêm khóa dd/MM để đọc được đăng ký cũ.
        dayKeyByDate[vnDate(d)] = _weekDayKeys[i];
        dayKeyByDate[_ddMM(d)] = _weekDayKeys[i];
      }
      final shiftNameById = {for (final s in templates) s.id: s.name};
      final wishes = <String, Map<String, String>>{};
      for (final r in rawRegs) {
        final empId = r['employeeId']?.toString() ?? '';
        final rawWeek = r['week']?.toString() ?? '';
        final dayKey = dayKeyByDate[toVnDate(rawWeek)] ?? dayKeyByDate[rawWeek];
        final shiftName = shiftNameById[r['shiftId']?.toString() ?? ''];
        if (empId.isEmpty || dayKey == null || shiftName == null) continue;
        (wishes[empId] ??= {})[dayKey] = shiftName;
      }

      // 4. Ca đã xếp.
      final shifts = await ShiftRepository().getShifts(branchSlug: branch?.slug);
      final staffById = {for (final s in staff) s.id: s};
      final assignments = {
        for (final k in _weekDayKeys) k: {for (final s in templates) s.name: <AssignedStaff>[]},
      };
      final monPure = DateTime(monday.year, monday.month, monday.day);
      for (final s in shifts) {
        final sDate = _parseShiftDate(s.date);
        if (sDate == null) continue;
        final diffDays = DateTime(sDate.year, sDate.month, sDate.day).difference(monPure).inDays;
        if (diffDays < 0 || diffDays >= 7) continue;
        final dayKey = _weekDayKeys[diffDays];
        final matched = s.employeeId == null ? null : staffById[s.employeeId];
        final templateName = s.template.isEmpty ? '—' : s.template;
        assignments[dayKey]![templateName] ??= [];
        assignments[dayKey]![templateName]!.add(AssignedStaff(
          id: matched?.id ?? s.employeeId ?? '',
          name: matched?.name ?? '—',
          role: matched?.role ?? '',
          avatarText: matched?.avatarText ?? '—',
          isRecurring: s.isRecurring,
          shiftId: s.id,
        ));
      }

      if (!mounted) return;
      setState(() {
        _availableShifts = templates;
        _branchEmployees = staff;
        _registrations = wishes.entries
            .map((e) => EmployeeShiftRegistration(employeeId: e.key, days: e.value))
            .toList();
        _assignments = assignments;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = _errorText(e));
    }
  }

  /// Ca chưa ghi template vẫn phải hiện, nếu không sẽ mất phân công thật.
  List<ShiftInfo> _shiftsForDay(String dayKey) {
    final known = {for (final s in _availableShifts) s.name};
    final extra = (_assignments[dayKey]?.keys ?? const Iterable<String>.empty())
        .where((k) => !known.contains(k))
        .map((k) => ShiftInfo(
              id: k,
              name: k,
              timeRange: '—',
              icon: FontAwesomeIcons.briefcase,
              color: const Color(0xFF616161),
            ));
    return [..._availableShifts, ...extra];
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

  Future<void> _addStaffToShift(String dayKey, String shiftName, AssignedStaff staff) async {
    final dayIndex = _weekDayKeys.indexOf(dayKey);
    if (dayIndex < 0) return;
    final matched = _availableShifts.where((s) => s.name == shiftName).toList();
    if (matched.isEmpty) {
      _showError('Không tìm thấy khung ca "$shiftName" trên hệ thống.');
      return;
    }
    final shiftInfo = matched.first;
    if (!shiftInfo.hasSchedule) {
      _showError('Khung ca "$shiftName" chưa có giờ làm nên không thể xếp ca.');
      return;
    }
    final branch = BranchScope.read(context)?.notifier?.value;
    final branchSlug = (branch != null && branch.slug.isNotEmpty)
        ? branch.slug
        : (widget.currentUser.branchSlug ?? '');
    if (branchSlug.isEmpty) {
      _showError('Chọn chi nhánh trước khi xếp ca.');
      return;
    }
    final targetDate = _thisWeekMonday.add(Duration(days: _weekOffset * 7 + dayIndex));
    final dateStr = vnDate(targetDate);

    try {
      final created = await ShiftRepository().createShift({
        'employeeId': staff.id,
        'branchSlug': branchSlug,
        'date': dateStr,
        'template': shiftName,
        'scheduledStart': shiftInfo.startTime,
        'scheduledEnd': shiftInfo.endTime,
        'status': 'Chưa chấm công',
        'note': '',
        'isRecurring': staff.isRecurring,
      });
      if (!mounted) return;
      setState(() {
        staff.shiftId = created.id;
        _assignments[dayKey] ??= {};
        _assignments[dayKey]![shiftName] ??= [];
        _assignments[dayKey]![shiftName]!.add(staff);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Đã thêm ${staff.name} vào $shiftName (${staff.isRecurring ? 'Lặp lại hàng tuần' : '1 lần'})'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadApiData();
    } catch (e) {
      _showError('Không xếp được ${staff.name} vào $shiftName: ${_errorText(e)}');
    }
  }

  Future<void> _removeStaffFromShift(String dayKey, String shiftName, AssignedStaff staff) async {
    final shiftId = staff.shiftId;
    if (shiftId == null || shiftId.isEmpty) {
      _showError('Ca này chưa có mã trên hệ thống nên không gỡ được.');
      return;
    }
    try {
      await ShiftRepository().deleteShift(shiftId);
    } catch (e) {
      _showError('Không gỡ được ${staff.name} khỏi $shiftName: ${_errorText(e)}');
      return;
    }
    if (!mounted) return;
    setState(() {
      _assignments[dayKey]?[shiftName]?.removeWhere((s) => s.shiftId == shiftId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gỡ ${staff.name} khỏi $shiftName'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _loadApiData();
  }

  Future<void> _toggleRecurring(String dayKey, String shiftName, AssignedStaff staff) async {
    final shiftId = staff.shiftId;
    if (shiftId == null || shiftId.isEmpty) {
      _showError('Ca này chưa có mã trên hệ thống nên không đổi được chế độ lặp.');
      return;
    }
    final next = !staff.isRecurring;
    try {
      await ShiftRepository().updateShift(shiftId, {'isRecurring': next});
    } catch (e) {
      _showError('Không lưu được chế độ lặp: ${_errorText(e)}');
      return;
    }
    if (!mounted) return;
    setState(() => staff.isRecurring = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next
            ? 'Đã bật lặp lại hàng tuần cho ${staff.name}'
            : 'Đã đổi sang phân công 1 lần cho ${staff.name}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Phân ca làm việc',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: const [
          BranchSelector(includeAll: true),
        ],
      ),
      body: _buildSchedulingView(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: XẾP CA (Giao diện 1 cột tối ưu cho Mobile, có thanh chọn ngày)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSchedulingView() {
    final dayKey = _weekDayKeys[_selectedDayIndex];
    final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));

    return Column(
      children: [
        // 1. THANH CHỌN NGÀY (WeekDayStrip - mũi tên overlay + fade)
        WeekDayStrip(
          weekLabel: '${_getWeekTitle(_weekOffset)}  •  ${_getWeekRange(_weekOffset)}',
          days: List.generate(7, (index) {
            final dayDate = monday.add(Duration(days: index));
            final isDayToday = dayDate.year == _today.year && dayDate.month == _today.month && dayDate.day == _today.day;
            final key = _weekDayKeys[index];
            final totalStaffOnDay = _assignments[key]?.values.fold(0, (sum, list) => sum + list.length) ?? 0;
            return {
              'label': key,
              'day': dayDate.day,
              'isToday': isDayToday,
              'dotColor': totalStaffOnDay > 0 ? AppColors.primary : (isDayToday ? AppColors.primary : null),
            };
          }),
          selectedIndex: _selectedDayIndex,
          onDaySelected: (index) => setState(() => _selectedDayIndex = index),
          onPrevWeek: () {
            setState(() => _weekOffset--);
            _loadApiData();
          },
          onNextWeek: () {
            setState(() => _weekOffset++);
            _loadApiData();
          },
        ),
        const Divider(height: 1),

        // 2. DANH SÁCH CÁC CA LÀM VIỆC TRONG NGÀY
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadApiData,
            color: AppColors.primary,
            child: ListView(
            padding: const EdgeInsets.all(14.0),
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
              ..._shiftsForDay(dayKey).map((shift) {
                final isExpanded = _expandedShiftIds.contains(shift.id);
                return _buildShiftAccordion(dayKey, shift, isExpanded);
              }),
              if (_shiftsForDay(dayKey).isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      FaIcon(FontAwesomeIcons.calendarXmark, size: 34, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        'Chưa có khung ca nào trên hệ thống.\nQuản lý cần tạo ca mẫu trước khi xếp ca.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ],
  );
}

  // Widget hiển thị từng ca làm việc (Accordion xổ xuống nhân viên)
  Widget _buildShiftAccordion(String dayKey, ShiftInfo shift, bool isExpanded) {
    final staffList = _assignments[dayKey]?[shift.name] ?? [];

    final Color cardBorderColor = isExpanded ? shift.color.withValues(alpha: 0.45) : Colors.grey.shade300;

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
                ? shift.color.withValues(alpha: 0.08)
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
                    backgroundColor: shift.color.withValues(alpha: 0.12),
                    child: FaIcon(shift.icon, color: shift.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shift.timeRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge số lượng nhân sự
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: staffList.isEmpty ? Colors.grey.shade100 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: staffList.isEmpty ? Colors.grey.shade300 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      '${staffList.length} NV',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: staffList.isEmpty ? Colors.grey.shade600 : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Nút dấu cộng (+) để thêm nhân viên
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.circlePlus, color: AppColors.primary, size: 26),
                    tooltip: 'Thêm nhân viên vào ca',
                    onPressed: () => _showAddStaffModal(dayKey, shift),
                  ),

                  // Mũi tên xổ xuống
                  FaIcon(
                    isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    color: isExpanded ? AppColors.primary : Colors.grey.shade500,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Phần xổ xuống: Danh sách các nhân viên đã được xếp
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: staffList.isEmpty
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
                            'Nhân viên trực ca (${staffList.length}):',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        ...staffList.map((staff) => _buildStaffItem(dayKey, shift, staff)),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // Thẻ của từng nhân viên đã được xếp trong ca (Kèm NÚT LẶP LẠI & NÚT XÓA)
  Widget _buildStaffItem(String dayKey, ShiftInfo shift, AssignedStaff staff) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                staff.avatarText,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    staff.role,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // NÚT LẶP LẠI (Tương tác bấm bật/tắt lặp lại hàng tuần)
            InkWell(
              onTap: () => _toggleRecurring(dayKey, shift.name, staff),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: staff.isRecurring ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: staff.isRecurring ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      staff.isRecurring ? FontAwesomeIcons.repeat : FontAwesomeIcons.one,
                      size: 13,
                      color: staff.isRecurring ? const Color(0xFF1D4ED8) : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      staff.isRecurring ? 'Lặp lại' : '1 lần',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: staff.isRecurring ? const Color(0xFF1D4ED8) : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Nút xóa nhân viên khỏi ca
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.circleMinus, color: Colors.redAccent, size: 20),
              tooltip: 'Gỡ khỏi ca',
              onPressed: () => _removeStaffFromShift(dayKey, shift.name, staff),
            ),
          ],
        ),
      ),
    );
  }

  // MODAL KHI BẤM DẤU CỘNG (+): MỖI NHÂN VIÊN SẼ CÓ MỘT CÁI NÚT LÀ LẶP LẠI
  void _showAddStaffModal(String dayKey, ShiftInfo shift) {
    final currentStaff = _assignments[dayKey]?[shift.name] ?? [];
    final currentStaffIds = currentStaff.map((s) => s.id).toSet();

    // Map lưu trạng thái lặp lại cho từng nhân viên trong modal
    final Map<String, bool> localRecurring = {
      for (var emp in _branchEmployees) emp.id: true,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dayName = _weekDayFullNames[_selectedDayIndex];
            final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));
            final selectedDate = monday.add(Duration(days: _selectedDayIndex));
            final dateStr = vnDate(selectedDate);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(modalCtx).padding.bottom + 16,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Modal
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: shift.color.withValues(alpha: 0.12),
                        child: FaIcon(shift.icon, color: shift.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thêm nhân viên vào ${shift.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            Text(
                              '$dayName ($dayKey), Ngày $dateStr • ${shift.timeRange}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 20, color: Colors.grey),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  const Text(
                    'Chọn nhân sự để xếp vào ca (Có thể bật lặp lại hàng tuần):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),

                  // Danh sách nhân sự chi nhánh
                  Expanded(
                    child: ListView.separated(
                      itemCount: _branchEmployees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final emp = _branchEmployees[idx];
                        final isAlreadyInShift = currentStaffIds.contains(emp.id);
                        final isRec = localRecurring[emp.id] ?? true;

                        // Nguyện vọng của nhân viên này
                        final reg = _registrations.where((r) => r.employeeId == emp.id).firstOrNull;
                        final bool matchesWish = reg?.days[dayKey] == shift.name;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAlreadyInShift ? Colors.grey.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAlreadyInShift ? Colors.grey.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  emp.avatarText,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emp.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isAlreadyInShift ? Colors.grey.shade600 : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          emp.role,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        if (matchesWish)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.amber.shade300),
                                            ),
                                            child: const Text(
                                              '⭐ Muốn làm ca này',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (isAlreadyInShift) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✓ Đã xếp',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                  ),
                                ),
                              ] else ...[
                                // NÚT LẶP LẠI (CHO MỖI NHÂN VIÊN)
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      localRecurring[emp.id] = !isRec;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isRec ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isRec ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FaIcon(
                                          isRec ? FontAwesomeIcons.repeat : FontAwesomeIcons.one,
                                          size: 13,
                                          color: isRec ? const Color(0xFF1D4ED8) : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isRec ? 'Lặp lại' : '1 lần',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: isRec ? const Color(0xFF1D4ED8) : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Nút + Thêm
                                ElevatedButton(
                                  onPressed: () {
                                    _addStaffToShift(
                                      dayKey,
                                      shift.name,
                                      AssignedStaff(
                                        id: emp.id,
                                        name: emp.name,
                                        role: emp.role,
                                        avatarText: emp.avatarText,
                                        isRecurring: isRec,
                                      ),
                                    );
                                    setModalState(() {
                                      currentStaffIds.add(emp.id);
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('+ Thêm'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
