import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/widgets/week_strip.dart';
import 'shift_repository.dart';

class ShiftOption {
  final String id;
  final String name;
  final String timeRange;

  const ShiftOption({
    required this.id,
    required this.name,
    required this.timeRange,
  });

  String get displayName => id == 'off' ? name : '$name ($timeRange)';
}

// Danh sách ca mẫu chuẩn (đồng bộ từ backend GET /api/shift-templates)
List<ShiftOption> adminShiftTemplates = [
  const ShiftOption(id: 'off', name: 'Nghỉ (Không làm ca)', timeRange: 'Nghỉ ca'),
];

class DayShiftRegistration {
  final String dayName;
  final String dateStr;
  final String shortKey;
  final Set<String> selectedShiftIds;

  DayShiftRegistration({
    required this.dayName,
    required this.dateStr,
    required this.shortKey,
    Set<String>? selectedShiftIds,
  }) : selectedShiftIds = selectedShiftIds ?? <String>{};

  bool get isOff => selectedShiftIds.isEmpty;

  bool isShiftSelected(String shiftId) {
    if (selectedShiftIds.contains(shiftId)) return true;
    final target = adminShiftTemplates.firstWhere(
      (s) => s.id == shiftId,
      orElse: () => ShiftOption(id: shiftId, name: shiftId, timeRange: ''),
    );
    for (final id in selectedShiftIds) {
      if (id == target.id || id.toLowerCase() == target.name.toLowerCase()) return true;
      final sel = adminShiftTemplates.firstWhere(
        (s) => s.id == id,
        orElse: () => ShiftOption(id: id, name: id, timeRange: ''),
      );
      if (sel.name.toLowerCase() == target.name.toLowerCase()) return true;
    }
    return false;
  }
}

/// Model lưu dữ liệu đăng ký ca theo từng tuần
class WeekRegistrationData {
  final String weekLabel;
  final List<DayShiftRegistration> days;
  String? note;
  bool noteSent;

  WeekRegistrationData({
    required this.weekLabel,
    required this.days,
    this.note,
    this.noteSent = false,
  });
}

class ScheduleRegistrationScreen extends StatefulWidget {
  const ScheduleRegistrationScreen({super.key});

  @override
  State<ScheduleRegistrationScreen> createState() => _ScheduleRegistrationScreenState();
}

class _ScheduleRegistrationScreenState extends State<ScheduleRegistrationScreen> {
  // Offset tuần so với tuần này: 0 = tuần này, 1 = tuần sau, 2 = 2 tuần sau...
  int _weekOffset = 1;

  // Ngày đang được chọn trong tuần (0: Thứ 2 -> 6: Chủ Nhật)
  int _selectedDayIndex = 0;

  // Cache dữ liệu tuần
  final Map<int, WeekRegistrationData> _weekDataCache = {};

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _thisWeekMonday {
    return _today.subtract(Duration(days: _today.weekday - 1));
  }

  DateTime _getWeekMonday(int offset) {
    return _thisWeekMonday.add(Duration(days: offset * 7));
  }

  String _getWeekRange(int offset) {
    final monday = _getWeekMonday(offset);
    final sunday = monday.add(const Duration(days: 6));
    final monStr = '${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')}';
    final sunStr = '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    return '$monStr - $sunStr';
  }

  String _getWeekTitle(int offset) {
    if (offset == 0) return 'Tuần này';
    if (offset == -1) return 'Tuần trước';
    if (offset == 1) return 'Tuần sau';
    if (offset < -1) return '${offset.abs()} tuần trước';
    return '$offset tuần sau';
  }

  WeekRegistrationData _getOrCreateWeekData(int offset) {
    if (_weekDataCache.containsKey(offset)) {
      return _weekDataCache[offset]!;
    }

    final monday = _getWeekMonday(offset);
    final dayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final shortKeys = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    final days = List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';
      return DayShiftRegistration(
        dayName: dayNames[i],
        dateStr: dateStr,
        shortKey: shortKeys[i],
        selectedShiftIds: <String>{},
      );
    });

    final weekData = WeekRegistrationData(
      weekLabel: _getWeekRange(offset),
      days: days,
    );
    _weekDataCache[offset] = weekData;
    return weekData;
  }

  WeekRegistrationData get _currentWeekData => _getOrCreateWeekData(_weekOffset);
  bool get _isPastWeek => _weekOffset < 0;

  @override
  void initState() {
    super.initState();
    // Nếu là tuần hiện tại thì tự chọn ngày hôm nay
    if (_weekOffset == 0) {
      _selectedDayIndex = (_today.weekday - 1).clamp(0, 6);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemoteRegistrations();
    });
  }

  Future<void> _loadRemoteRegistrations() async {
    try {
      final user = UserScope.currentUser(context);
      final empId = user?.id ?? '';
      final repo = ShiftRepository();
      try {
        final tpls = await repo.getTemplates();
        if (tpls.isNotEmpty) {
          final List<ShiftOption> loaded = [
            const ShiftOption(id: 'off', name: 'Nghỉ (Không làm ca)', timeRange: 'Nghỉ ca'),
          ];
          for (final t in tpls) {
            final id = t['id']?.toString() ?? '';
            final name = t['name']?.toString() ?? '';
            final start = t['startTime']?.toString() ?? '';
            final end = t['endTime']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              loaded.add(ShiftOption(
                id: id,
                name: name,
                timeRange: start.isNotEmpty && end.isNotEmpty ? '$start - $end' : start,
              ));
            }
          }
          if (loaded.length > 1) {
            adminShiftTemplates = loaded;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('❌ Không tải được khung ca: ${e is ApiException ? e.message : e}'),
            ),
          );
        }
      }

      final regs = empId.isNotEmpty
          ? await repo.getRegistrations(employeeId: empId)
          : <Map<String, dynamic>>[];
      if (mounted) {
        final weekData = _getOrCreateWeekData(_weekOffset);
        for (final day in weekData.days) {
          day.selectedShiftIds.clear();
        }
        for (final r in regs) {
          final pref = r['preference']?.toString() ?? r['week']?.toString() ?? '';
          final shiftId = r['shiftId']?.toString() ?? '';
          if (shiftId != 'preference_note' && shiftId.isNotEmpty && shiftId != 'off') {
            for (final day in weekData.days) {
              if (day.dateStr == pref ||
                  pref.contains(day.dateStr) ||
                  day.shortKey.toUpperCase() == pref.toUpperCase()) {
                day.selectedShiftIds.add(shiftId);
              }
            }
          }
        }
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ Không tải được đăng ký ca: ${e is ApiException ? e.message : e}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onWeekChanged(int newOffset) {
    setState(() {
      _weekOffset = newOffset;
      _selectedDayIndex = 0;
    });
    _loadRemoteRegistrations();
  }

  Future<void> _onToggleShift(DayShiftRegistration day, ShiftOption shift) async {
    final user = UserScope.currentUser(context);
    final empId = user?.id ?? '';
    final branch = BranchScope.selectedBranch(context);
    final branchSlug = branch?.slug ?? user?.branchSlug ?? user?.assignedBranchId;
    final isCurrentlyRegistered = day.isShiftSelected(shift.id);

    if (empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ Không xác định được tài khoản, vui lòng đăng nhập lại'),
        ),
      );
      return;
    }

    // Chỉ đổi trạng thái ô chọn khi server đã ghi nhận, không báo trước thành công.
    try {
      if (isCurrentlyRegistered) {
        await ShiftRepository().unregisterShift(
          employeeId: empId,
          shiftId: shift.id,
          preference: day.dateStr,
        );
      } else {
        await ShiftRepository().registerShift(
          employeeId: empId,
          shiftId: shift.id,
          preference: day.dateStr,
          branchSlug: branchSlug,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ ${e is ApiException ? e.message : 'Không lưu được đăng ký ca, vui lòng thử lại.'}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      if (isCurrentlyRegistered) {
        day.selectedShiftIds.removeWhere((id) {
          if (id == shift.id) return true;
          final match = adminShiftTemplates.firstWhere(
            (s) => s.id == id,
            orElse: () => ShiftOption(id: id, name: id, timeRange: ''),
          );
          return match.name.toLowerCase() == shift.name.toLowerCase();
        });
      } else {
        day.selectedShiftIds.add(shift.id);
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            FaIcon(
              isCurrentlyRegistered ? FontAwesomeIcons.circleMinus : FontAwesomeIcons.circleCheck,
              color: isCurrentlyRegistered ? Colors.amberAccent : Colors.greenAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCurrentlyRegistered
                    ? '${day.dayName}: Đã hủy đăng ký ${shift.name}'
                    : '${day.dayName}: Đã đăng ký ${shift.name} (${shift.timeRange})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getShiftIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sáng') || lower.contains('morning')) return Icons.wb_sunny_rounded;
    if (lower.contains('chiều') || lower.contains('afternoon')) return Icons.wb_twilight_rounded;
    if (lower.contains('tối') || lower.contains('night') || lower.contains('evening')) return Icons.nightlight_round;
    if (lower.contains('hành chính') || lower.contains('office') || lower.contains('full')) return Icons.work_outline_rounded;
    return Icons.access_time_rounded;
  }

  Color _getShiftColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sáng')) return Colors.amber.shade700;
    if (lower.contains('chiều')) return Colors.orange.shade700;
    if (lower.contains('tối')) return Colors.indigo.shade600;
    if (lower.contains('hành chính')) return Colors.teal.shade700;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final weekData = _currentWeekData;
    final selectedDay = weekData.days[_selectedDayIndex.clamp(0, 6)];
    final availableShifts = adminShiftTemplates.where((s) => s.id != 'off').toList();
    final isLocked = _isPastWeek;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Đăng ký ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          BranchSelector(includeAll: true),
        ],
      ),
      body: Column(
        children: [
          // ── THANH CHỌN TUẦN & 7 NGÀY (DÙNG CHUNG WeekDayStrip NHƯ LỊCH LÀM VIỆC CHUNG) ──
          WeekDayStrip(
            weekLabel: '${_getWeekTitle(_weekOffset)}  •  ${_getWeekRange(_weekOffset)}',
            days: List.generate(weekData.days.length, (index) {
              final day = weekData.days[index];
              final parts = day.dateStr.split('/');
              final dayNum = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
              final isToday = day.dayName == 'Hôm nay' ||
                  (day.dateStr ==
                      '${_today.day.toString().padLeft(2, '0')}/${_today.month.toString().padLeft(2, '0')}');
              final hasRegistered = !day.isOff;
              return {
                'label': day.shortKey,
                'day': dayNum,
                'isToday': isToday,
                'dotColor': hasRegistered ? AppColors.primary : Colors.grey.shade300,
              };
            }),
            selectedIndex: _selectedDayIndex.clamp(0, 6),
            onDaySelected: (index) => setState(() => _selectedDayIndex = index),
            onPrevWeek: () => _onWeekChanged(_weekOffset - 1),
            onNextWeek: () => _onWeekChanged(_weekOffset + 1),
          ),
          const Divider(height: 1),

          // ── DANH SÁCH CÁC CA LÀM VIỆC CỦA NGÀY ĐANG CHỌN ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Danh sách ca của ngày đang chọn
                ...availableShifts.map((shift) {
                  final isRegistered = selectedDay.isShiftSelected(shift.id);
                  final shiftColor = _getShiftColor(shift.name);
                  final shiftIcon = _getShiftIcon(shift.name);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: isRegistered ? 1 : 0.3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isRegistered
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        width: isRegistered ? 1.5 : 1.0,
                      ),
                    ),
                    color: isRegistered
                        ? AppColors.primary.withValues(alpha: 0.04)
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Icon ca làm việc
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isRegistered
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : shiftColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                shiftIcon,
                                size: 22,
                                color: isRegistered ? AppColors.primary : shiftColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Tên ca & Giờ làm
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      shift.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isRegistered ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isRegistered) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Đã đăng ký',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.clock, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 5),
                                    Text(
                                      shift.timeRange,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Nút dấu cộng (+) để đăng ký ca
                          if (!isLocked)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _onToggleShift(selectedDay, shift);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isRegistered
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isRegistered
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(alpha: 0.25),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: FaIcon(
                                      isRegistered ? FontAwesomeIcons.check : FontAwesomeIcons.plus,
                                      size: 16,
                                      color: isRegistered ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: FaIcon(
                                  isRegistered ? FontAwesomeIcons.check : FontAwesomeIcons.lock,
                                  size: 14,
                                  color: isRegistered ? AppColors.primary : Colors.grey.shade400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
