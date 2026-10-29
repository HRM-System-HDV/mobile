import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../attendance/attendance_repository.dart';
import '../attendance/adjustment.dart';
import 'schedule.dart';
import 'shift_form.dart';

class ShiftDetailScreen extends StatefulWidget {
  final ShiftDetail shift;
  final String date;
  final String dayOfWeek;

  const ShiftDetailScreen({
    super.key,
    required this.shift,
    required this.date,
    required this.dayOfWeek,
  });

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  String? _realCheckIn;
  String? _realCheckOut;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final records = await AttendanceRepository().getAttendance();
      if (records.isNotEmpty && mounted) {
        final match = records.where((r) => r.shiftId == widget.shift.id || r.shiftId == widget.shift.shiftName).firstOrNull;
        if (match != null) {
          setState(() {
            _realCheckIn = match.checkIn;
            _realCheckOut = match.checkOut;
          });
        }
      }
    } catch (_) {}
  }

  void _navigateToForm(ShiftActionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShiftActionFormScreen(
          shift: widget.shift,
          date: widget.date,
          dayOfWeek: widget.dayOfWeek,
          actionType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;

    final Color statusColor = ScheduleService.getStatusColor(shift.status);
    final String statusText = ScheduleService.getStatusLabel(shift.status);

    // Chỉ dùng dữ liệu chấm công thật từ API.
    // Khi chưa có dữ liệu thật thì hiển thị '—' (chưa chấm công), không dùng giờ mẫu.
    final String checkIn = _realCheckIn ?? '—';
    final String checkOut = _realCheckOut ?? '—';
    final String tongGioTinhCong = shift.status == 'completed'
        ? '${shift.hours} giờ'
        : (shift.status == 'active'
            ? 'Đang tính...'
            : (shift.status == 'missed' ? '0.0 giờ' : '--'));
    final String nguonCong = (shift.status == 'upcoming' || shift.status == 'missed')
        ? 'Phân công (Quản lý)'
        : 'Hệ thống tự động';

    final user = UserScope.currentUser(context);
    final bool isHourly = user?.isHourlySalary ?? true;
    final double hourlySalary = user?.hourlySalary ?? 35000.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết ca làm việc'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Quay lại',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header tổng quan ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(FontAwesomeIcons.clock, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.shiftName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.dayOfWeek}, ${widget.date}/${DateTime.now().year} • ${shift.timeRange}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Thông tin chấm công ───────────────────────────────
            const Text(
              'Thông tin chấm công',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày tính công',
                      '${widget.date}/${DateTime.now().year} (${widget.dayOfWeek})'),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.user, 'Nhân viên',
                      UserScope.currentUser(context)?.name ?? '—'),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.briefcase, 'Ca làm việc', shift.shiftName),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.rightToBracket, 'Giờ check-in tính công', checkIn),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.rightFromBracket, 'Giờ check-out tính công', checkOut),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ tính công', tongGioTinhCong),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.flag, 'Trạng thái', statusText,
                      valueColor: statusColor),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.fileLines, 'Nguồn công', nguonCong),
                  if (shift.status == 'completed') ...[
                    _divider(),
                    _buildInfoRow(
                      FontAwesomeIcons.moneyBillWave,
                      'Cơ chế tính lương',
                      isHourly ? 'Theo giờ (${_formatCurrency(hourlySalary)} ₫/h)' : 'Lương cơ bản tháng',
                    ),
                    _divider(),
                    if (isHourly)
                      _buildInfoRow(
                        FontAwesomeIcons.circleDollarToSlot,
                        'Thu nhập ca cộng vào',
                        '+${_formatCurrency((shift.hours > 0 ? shift.hours : 5.0) * hourlySalary)} ₫',
                        valueColor: AppColors.success,
                      )
                    else
                      _buildInfoRow(
                        FontAwesomeIcons.circleExclamation,
                        'Khấu trừ phạt ca',
                        '0 ₫ (Không bị phạt)',
                        valueColor: Colors.green.shade700,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tác vụ ───────────────────────────────────────────
            if (shift.status == 'upcoming') ...[
              const Text(
                'Tùy chọn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                title: 'Nhờ làm thay',
                icon: FontAwesomeIcons.userPlus,
                color: Colors.orange.shade800,
                bgColor: Colors.orange.shade50,
                onTap: () => _navigateToForm(ShiftActionType.cover),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                title: 'Đổi ca làm việc',
                icon: FontAwesomeIcons.arrowsLeftRight,
                color: AppColors.primary,
                bgColor: AppColors.primary.withValues(alpha: 0.08),
                onTap: () => _navigateToForm(ShiftActionType.swap),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                title: 'Xin nghỉ ca',
                icon: FontAwesomeIcons.calendarXmark,
                color: Colors.red.shade700,
                bgColor: Colors.red.shade50,
                onTap: () => _navigateToForm(ShiftActionType.leave),
              ),
            ] else if (shift.status == 'missed') ...[
              _buildActionButton(
                title: 'Bổ sung chấm công',
                icon: FontAwesomeIcons.calendarPlus,
                color: Colors.orange.shade700,
                bgColor: Colors.orange.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AttendanceAdjustmentScreen()),
                  );
                },
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      shift.status == 'completed' ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleInfo,
                      color: shift.status == 'completed' ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        shift.status == 'completed'
                            ? 'Ca làm việc đã hoàn thành và được ghi nhận công.'
                            : 'Ca làm việc đang diễn ra.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(num value) {
    final str = value.toInt().toString();
    return str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _buildInfoRow(FaIconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          FaIcon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required FaIconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            FaIcon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            FaIcon(FontAwesomeIcons.chevronRight, color: color.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}
