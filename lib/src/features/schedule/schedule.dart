import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import 'schedule_service.dart';
import 'shift_repository.dart';
import 'shift_detail.dart';

export 'schedule_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Offset tuần so với tuần hiện tại (0: Tuần này, -1: Tuần trước, 1: Tuần sau, -2, 2, ...)
  int _weekOffset = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _thisWeekMonday => ScheduleService.getMonday(_today);

  // Set lưu các ngày đang được mở rộng (expanded)
  final Set<String> _expandedDays = {};
  List<ApiShiftModel> _apiShifts = [];

  @override
  void initState() {
    super.initState();
    final todayFormatted = '${_today.day.toString().padLeft(2, '0')}/${_today.month.toString().padLeft(2, '0')}';
    _expandedDays.add(todayFormatted);
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await ShiftRepository().getShifts();
      // Gán vô điều kiện kể cả rỗng để hiện empty-state, không giữ mock.
      if (mounted) {
        setState(() {
          _apiShifts = shifts;
        });
      }
    } catch (_) {
      // Chỉ dùng API thật: khi lỗi/offline giữ danh sách rỗng để hiện empty-state.
      if (mounted) {
        setState(() {
          _apiShifts = [];
        });
      }
    }
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

  List<DayScheduleModel> _getWeekData(int offset) {
    return ScheduleService.getWeekDataWithApi(
      offset: offset,
      apiShifts: _apiShifts,
    );
  }

  void _selectWeek(int offset) {
    setState(() {
      _weekOffset = offset;
      final weekDays = _getWeekData(offset);
      final firstWithShift = weekDays.firstWhere(
        (d) => !d.isOff,
        orElse: () => weekDays.first,
      );
      _expandedDays.clear();
      _expandedDays.add(firstWithShift.date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWeekDays = _getWeekData(_weekOffset);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch làm việc cá nhân'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadShifts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Chọn tuần làm việc với mũi tên tiến/lùi không giới hạn
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Chọn tuần làm việc:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_weekOffset != 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _selectWeek(0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(FontAwesomeIcons.rotateLeft, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Về tuần này',
                                style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _selectWeek(_weekOffset - 1),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: FaIcon(
                            FontAwesomeIcons.chevronLeft,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      InkWell(
                        onTap: () => _selectWeek(_weekOffset + 1),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: FaIcon(
                            FontAwesomeIcons.chevronRight,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3 tab trượt động theo tuần đang chọn
            Row(
              children: [
                _buildWeekTabItem(_weekOffset - 1, isSelected: false),
                const SizedBox(width: 8),
                _buildWeekTabItem(_weekOffset, isSelected: true),
                const SizedBox(width: 8),
                _buildWeekTabItem(_weekOffset + 1, isSelected: false),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Danh sách phân ca chi tiết theo ngày
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Lịch phân ca: ${_getWeekTitle(_weekOffset)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getWeekRange(_weekOffset),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Accordion List of Days
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentWeekDays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final dayModel = currentWeekDays[index];
                final isExpanded = _expandedDays.contains(dayModel.date);
                return _buildDayAccordion(dayModel, isExpanded);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildWeekTabItem(int offset, {required bool isSelected}) {
    final title = _getWeekTitle(offset);
    final range = _getWeekRange(offset);

    return Expanded(
      child: InkWell(
        onTap: () => _selectWeek(offset),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                range,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected ? Colors.white70 : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayAccordion(DayScheduleModel dayModel, bool isExpanded) {
    Color headerBorderColor = dayModel.isToday
        ? AppColors.primary
        : (isExpanded ? AppColors.primary.withValues(alpha: 0.45) : Colors.grey.shade300);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: headerBorderColor,
          width: dayModel.isToday ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: dayModel.isToday
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header of the Day (Clickable to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDays.remove(dayModel.date);
                } else {
                  _expandedDays.add(dayModel.date);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Day & Date Box
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: dayModel.isToday
                          ? AppColors.primary
                          : (dayModel.isOff ? Colors.grey.shade100 : AppColors.background),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayModel.dayOfWeek,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dayModel.isToday
                                ? Colors.white
                                : (dayModel.isOff ? Colors.grey : AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayModel.date,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dayModel.isToday ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Subtitle (Không hiện tổng giờ / số ca)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${dayModel.dayOfWeek}, ${dayModel.date}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: dayModel.isToday ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            if (dayModel.isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Hôm nay',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dayModel.isOff ? 'Ngày nghỉ (OFF)' : 'Có lịch làm việc',
                          style: TextStyle(
                            fontSize: 12,
                            color: dayModel.isOff ? Colors.grey : AppColors.textSecondary,
                            fontWeight: dayModel.isOff ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  FaIcon(
                    isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    color: isExpanded ? AppColors.primary : Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content (Div con hiển thị các ca làm việc của ngày đó)
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: dayModel.isOff
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Không có lịch làm việc trong ngày này',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: dayModel.shifts.map((shift) {
                        return _buildShiftItemCard(shift, dayModel.date, dayModel.dayOfWeek);
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftItemCard(ShiftDetail shift, String date, String dayOfWeek) {
    final Color statusColor = ScheduleService.getStatusColor(shift.status);
    final String statusText = ScheduleService.getStatusLabel(shift.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShiftDetailScreen(
                shift: shift,
                date: date,
                dayOfWeek: dayOfWeek,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Detail
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          shift.shiftName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.clock, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          shift.timeRange,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shift.role} • ${shift.branch}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Chevron indicator
              const FaIcon(FontAwesomeIcons.chevronRight, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
