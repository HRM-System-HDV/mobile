import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/widgets/week_strip.dart';
import '../../core/models/user.dart';
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
}

/// Model đơn đăng ký nguyện vọng của nhân viên
class EmployeeShiftRegistration {
  final String employeeName;
  final String role;
  final String avatarText;
  final int requestedShiftCount;
  final DateTime registeredAt;
  final int registrationOrder;
  final Map<String, String> days;
  final String? note;

  const EmployeeShiftRegistration({
    required this.employeeName,
    required this.role,
    required this.avatarText,
    required this.requestedShiftCount,
    required this.registeredAt,
    required this.registrationOrder,
    required this.days,
    this.note,
  });
}

class ShiftAssignmentScreen extends StatefulWidget {
  final UserModel currentUser;

  const ShiftAssignmentScreen({
    super.key,
    this.currentUser = const UserModel(
      name: 'Vũ Thành Công',
      email: 'manager@company.com',
      role: 'manager',
      roleTitle: 'Quản lý chi nhánh',
    ),
  });

  @override
  State<ShiftAssignmentScreen> createState() => _ShiftAssignmentScreenState();
}

class _ShiftAssignmentScreenState extends State<ShiftAssignmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tuần & ngày đang chọn
  int _weekOffset = 0;
  int _selectedDayIndex = 0;

  // Set các ID ca đang được mở rộng xổ xuống
  final Set<String> _expandedShiftIds = {'morning', 'afternoon'};

  // Danh sách các ca làm việc chuẩn
  final List<ShiftInfo> _availableShifts = const [
    ShiftInfo(
      id: 'morning',
      name: 'Ca Sáng',
      timeRange: '07:00 - 14:00',
      icon: FontAwesomeIcons.sun,
      color: Color(0xFFE65100),
    ),
    ShiftInfo(
      id: 'afternoon',
      name: 'Ca Chiều',
      timeRange: '14:00 - 22:00',
      icon: FontAwesomeIcons.cloudSun,
      color: Color(0xFF0277BD),
    ),
    ShiftInfo(
      id: 'evening',
      name: 'Ca Tối',
      timeRange: '18:00 - 23:00',
      icon: FontAwesomeIcons.moon,
      color: Color(0xFF4A148C),
    ),
    ShiftInfo(
      id: 'admin',
      name: 'Ca Hành chính',
      timeRange: '08:00 - 17:00',
      icon: FontAwesomeIcons.briefcase,
      color: Color(0xFF00695C),
    ),
  ];

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
    final monStr = '${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')}';
    final sunStr = '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    return '$monStr - $sunStr';
  }

  String? _loadedBranchSlug;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _loadApiData() async {
    try {
      final branch = BranchScope.read(context)?.notifier?.value;
      final employees = await EmployeeRepository().getEmployees();
      if (mounted) {
        setState(() {
          _branchEmployees = employees.map((e) {
            final id = e['id']?.toString() ?? '';
            final name = e['name']?.toString() ?? 'Chưa phân công';
            final role = e['role']?.toString() ?? 'Nhân viên';
            final avatar = name.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();
            return AssignedStaff(
              id: id,
              name: name.isEmpty ? 'Chưa phân công' : name,
              role: role,
              avatarText: avatar.isNotEmpty ? avatar : 'NV',
            );
          }).toList();
        });
      }

      final rawRegs = await ShiftRepository().getRegistrations();
      if (mounted) {
        final Map<String, Map<String, String>> empWishes = {};
        for (final r in rawRegs) {
          final empId = r['employeeId']?.toString() ?? '';
          final emp = _branchEmployees.where((e) => e.id == empId).firstOrNull;
          final rawName = r['employeeName']?.toString() ?? '';
          final empName = emp?.name ?? (rawName.isNotEmpty ? rawName : 'Chưa phân công');
          empWishes.putIfAbsent(empName, () => {});
          final wish = r['wish']?.toString() ?? r['shiftId']?.toString() ?? 'Ca Sáng';
          final day = r['day']?.toString() ?? 'T2';
          empWishes[empName]![day] = wish;
        }

        final mappedRegs = empWishes.entries.map((entry) {
          final emp = _branchEmployees.where((e) => e.name == entry.key).firstOrNull;
          return EmployeeShiftRegistration(
            employeeName: entry.key,
            role: emp?.role ?? 'Nhân viên',
            avatarText: emp?.avatarText ?? (entry.key.isNotEmpty ? entry.key[0] : 'NV'),
            requestedShiftCount: entry.value.length,
            registeredAt: DateTime.now(),
            registrationOrder: 1,
            days: entry.value,
          );
        }).toList();

        setState(() {
          _registrations = mappedRegs;
        });
      }

      final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));
      final shifts = await ShiftRepository().getShifts(branchSlug: branch?.slug);
      if (mounted) {
        final Map<String, Map<String, List<AssignedStaff>>> newAssignments = {};
        for (final k in _weekDayKeys) {
          newAssignments[k] = {
            for (final s in _availableShifts) s.name: <AssignedStaff>[],
          };
        }

        // Map id nhân viên -> tên thật từ API
        final empNameById = {for (final e in _branchEmployees) e.id: e};
        for (final s in shifts) {
          DateTime? sDate;
          try {
            if (s.date.contains('-')) {
              final parts = s.date.split('-');
              if (parts[0].length == 4) {
                sDate = DateTime.parse(s.date);
              } else if (parts.length == 3) {
                sDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } else if (s.date.contains('/')) {
              final parts = s.date.split('/');
              if (parts.length == 3) {
                sDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
          } catch (_) {}

          if (sDate != null) {
            final diffDays = sDate.difference(monday).inDays;
            if (diffDays >= 0 && diffDays < 7) {
              final dayKey = _weekDayKeys[diffDays];
              final matched = s.employeeId != null ? empNameById[s.employeeId] : null;
              final staff = (matched != null)
                  ? AssignedStaff(
                      id: matched.id,
                      name: matched.name,
                      role: matched.role,
                      avatarText: matched.avatarText,
                      isRecurring: true,
                      shiftId: s.id,
                    )
                  : AssignedStaff(
                      id: s.employeeId ?? s.id,
                      name: 'Chưa phân công',
                      role: 'Nhân viên',
                      avatarText: 'NV',
                      shiftId: s.id,
                    );
              final templateName = s.template.isEmpty ? 'Ca Sáng' : s.template;
              newAssignments[dayKey] ??= {};
              newAssignments[dayKey]![templateName] ??= [];
              newAssignments[dayKey]![templateName]!.add(staff);
            }
          }
        }

        setState(() {
          _assignments = newAssignments;
        });
      }
    } catch (_) {
      // Lỗi API: giữ state rỗng để hiện empty state, không dùng mock
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    setState(() {
      _assignments[dayKey] ??= {};
      _assignments[dayKey]![shiftName] ??= [];
      _assignments[dayKey]![shiftName]!.add(staff);
    });

    final dayIndex = _weekDayKeys.indexOf(dayKey);
    final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));
    final targetDate = monday.add(Duration(days: dayIndex >= 0 ? dayIndex : 0));
    final dateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final shiftInfo = _availableShifts.firstWhere(
      (s) => s.name == shiftName,
      orElse: () => _availableShifts.first,
    );
    final branch = BranchScope.read(context)?.notifier?.value;

    try {
      final created = await ShiftRepository().createShift({
        'employeeId': staff.id,
        'date': dateStr,
        'template': shiftName,
        'scheduledStart': shiftInfo.startTime,
        'scheduledEnd': shiftInfo.endTime,
        'branchSlug': branch?.slug,
        'status': 'scheduled',
      });
      staff.shiftId = created.id;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${staff.name} vào $shiftName (${staff.isRecurring ? 'Lặp lại hàng tuần' : '1 lần'})'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeStaffFromShift(String dayKey, String shiftName, AssignedStaff staff) {
    if (staff.shiftId != null && staff.shiftId!.isNotEmpty) {
      ShiftRepository().deleteShift(staff.shiftId!).catchError((_) {});
    }
    setState(() {
      _assignments[dayKey]?[shiftName]?.removeWhere((s) => s.id == staff.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gỡ ${staff.name} khỏi $shiftName'),
        duration: const Duration(seconds: 1),
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
          'Xếp ca',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: const [
          BranchSelector(includeAll: true),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Xếp ca'),
            Tab(text: 'Nguyện vọng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchedulingView(),
          _buildEmployeeListView(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: XẾP CA (Giao diện 1 cột tối ưu cho Mobile, có thanh chọn ngày)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSchedulingView() {
    final dayKey = _weekDayKeys[_selectedDayIndex];
    final dayFullName = _weekDayFullNames[_selectedDayIndex];
    final monday = _thisWeekMonday.add(Duration(days: _weekOffset * 7));
    final selectedDate = monday.add(Duration(days: _selectedDayIndex));
    final isToday = selectedDate.year == _today.year && selectedDate.month == _today.month && selectedDate.day == _today.day;
    final dateFormatted = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '$dayFullName, $dateFormatted/${DateTime.now().year}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Hôm nay',
                            style: TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${_availableShifts.length} ca làm',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Bấm vào ca để xổ xuống danh sách nhân viên • Bấm dấu (+) để thêm',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // Hiển thị danh sách các ca làm việc
              ..._availableShifts.map((shift) {
                final isExpanded = _expandedShiftIds.contains(shift.id);
                return _buildShiftAccordion(dayKey, shift, isExpanded);
              }),

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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nhân viên trực ca (${staffList.length}):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showAddStaffModal(dayKey, shift),
                                icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: AppColors.primary),
                                label: const Text(
                                  'Thêm người',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
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
              onTap: () {
                setState(() {
                  staff.isRecurring = !staff.isRecurring;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      staff.isRecurring
                          ? 'Đã bật lặp lại hàng tuần cho ${staff.name}'
                          : 'Đã đổi sang phân công 1 lần cho ${staff.name}',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
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
            final dateStr = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}';

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
                        final reg = _registrations.where((r) => r.employeeName == emp.name).firstOrNull;
                        final wish = reg?.days[dayKey];
                        final bool matchesWish = wish == shift.name;
                        final bool wantsOff = wish == 'Nghỉ';

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
                                    Row(
                                      children: [
                                        Text(
                                          emp.role,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        if (matchesWish) ...[
                                          const SizedBox(width: 6),
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
                                        ] else if (wantsOff) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.red.shade200),
                                            ),
                                            child: const Text(
                                              'Xin nghỉ',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red),
                                            ),
                                          ),
                                        ],
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

  // ─────────────────────────────────────────────────────────────
  // TAB 2: NGUYỆN VỌNG ĐĂNG KÝ CỦA NHÂN SỰ
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmployeeListView() {
    return RefreshIndicator(
      onRefresh: _loadApiData,
      color: AppColors.primary,
      child: _registrations.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              children: [
                Center(
                  child: Column(
                    children: [
                      FaIcon(FontAwesomeIcons.clipboardList, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Chưa có đơn đăng ký ca nào cho tuần này',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                ..._registrations.map((reg) => _buildRegistrationCard(reg)),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildRegistrationCard(EmployeeShiftRegistration reg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(reg.avatarText, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reg.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${reg.role} • ${reg.requestedShiftCount} ca/tuần', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Lưới 7 ngày
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: reg.days.entries.map((e) {
                final bool isOff = e.value == 'Nghỉ';
                return Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isOff ? Colors.grey.shade100 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isOff ? Colors.grey.shade300 : Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(e.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(
                        isOff ? 'OFF' : e.value.replaceAll('Ca ', ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOff ? Colors.grey.shade600 : const Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            if (reg.note != null && reg.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'Note: ${reg.note!}',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade800, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
