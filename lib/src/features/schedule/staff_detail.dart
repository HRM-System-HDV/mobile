import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../attendance/attendance_repository.dart';
import '../attendance/adjustment.dart';
import 'shift_repository.dart';
import 'general.dart';

class StaffGeneralShiftDetailScreen extends StatelessWidget {
  final StaffInShift staff;
  final GeneralShiftModel shift;
  final GeneralDayModel day;

  const StaffGeneralShiftDetailScreen({
    super.key,
    required this.staff,
    required this.shift,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final isNotYet = staff.checkInStatus == 'not_yet';
    final isCheckedIn = staff.checkInStatus == 'checked_in';
    final isInProgress = staff.checkInStatus == 'in_progress';
    final isForgot = isNotYet && !day.isToday;
    bool isLate = false;
    if (isCheckedIn) {
      final startStr = shift.timeRange.split('-')[0].trim();
      final partsStart = startStr.split(':');
      final partsCheck = staff.checkInTime.split(':');
      if (partsStart.length == 2 && partsCheck.length == 2) {
        final sh = int.tryParse(partsStart[0]) ?? 0;
        final sm = int.tryParse(partsStart[1]) ?? 0;
        final ch = int.tryParse(partsCheck[0]) ?? 0;
        final cm = int.tryParse(partsCheck[1]) ?? 0;
        isLate = ch * 60 + cm - (sh * 60 + sm) > 5;
      }
    }

    String statusText;
    Color statusColor;
    if (isCheckedIn) {
      statusText = isLate ? 'Trễ' : 'Đúng giờ';
      statusColor = isLate ? Colors.orange.shade700 : AppColors.success;
    } else if (isInProgress) {
      statusText = 'Đang trong ca';
      statusColor = Colors.orange;
    } else if (isForgot) {
      statusText = 'Quên chấm công';
      statusColor = Colors.red.shade700;
    } else {
      statusText = 'Chưa chấm công';
      statusColor = Colors.grey;
    }

    final checkIn = staff.checkInTime.isNotEmpty ? staff.checkInTime : (isNotYet ? 'Chưa chấm công' : '--:--');
    final checkOut = isNotYet ? 'Chưa chấm công' : '--:--';
    final hours = isCheckedIn ? '4.0 giờ' : isInProgress ? 'Đang tính...' : '0.0 giờ';

    // Phân quyền theo tài khoản người dùng đang đăng nhập:
    // - Admin hoặc Manager: có toàn quyền xem và quản lý ca (Hủy ca, Chấm công) của mọi nhân viên.
    // - Nhân viên: chỉ được xem chi tiết ca của chính mình, KHÔNG được xem ca của người khác.
    final currentUser = UserScope.currentUser(context);
    final bool canManage = UserScope.canManage(context);
    final bool isOwnShift = currentUser != null &&
        currentUser.name.trim().toLowerCase() == staff.name.trim().toLowerCase();

    // Khóa màn hình nếu là nhân viên và không phải ca của chính mình
    if (!canManage && !isOwnShift) {
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
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(FontAwesomeIcons.lock, size: 36, color: Colors.amber.shade800),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Không có quyền truy cập',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ Quản trị viên và Quản lý mới có quyền xem chi tiết ca làm việc của nhân viên khác.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 140,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool showAdminActions = canManage;
    final bool showEmployeeSupplement = !canManage && isOwnShift;

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
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header chung - đồng bộ với ShiftDetailScreen
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const FaIcon(FontAwesomeIcons.clock, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shift.shiftName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${day.dayOfWeek}, ${day.date} • ${shift.timeRange}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Row(children: [
                          CircleAvatar(radius: 12, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(staff.name.split(' ').last.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11))),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${staff.name} • ${staff.role}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Thông tin chấm công', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày tính công', '${day.date}/${DateTime.now().year} (${day.dayOfWeek})'),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.user, 'Nhân viên', staff.name),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.briefcase, 'Ca làm việc', shift.shiftName),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.rightToBracket, 'Giờ check-in tính công', checkIn, valueColor: isForgot ? Colors.red.shade700 : null),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.rightFromBracket, 'Giờ check-out tính công', checkOut, valueColor: isForgot ? Colors.red.shade700 : null),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ tính công', hours),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.flag, 'Trạng thái', statusText, valueColor: statusColor),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.fileLines, 'Nguồn công', 'Phân công (Quản lý)'),
              ]),
            ),
            const SizedBox(height: 20),
            // Tùy chọn - chỉ hiển thị theo đúng phân quyền vai trò
            if (showAdminActions) ...[
              const Text('Tùy chọn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              if (isCheckedIn && !isLate) ...[
                // Đúng giờ: Quản lý / Admin có quyền Hủy ca
                _buildActionButton(
                  title: 'Hủy ca',
                  icon: FontAwesomeIcons.circleXmark,
                  color: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  onTap: () => _handleCancelShift(context),
                ),
              ] else ...[
                // Quên / Trễ / Chưa / Đang làm: Quản lý / Admin có quyền Hủy ca hoặc Chấm công dùm
                _buildActionButton(
                  title: 'Hủy ca',
                  icon: FontAwesomeIcons.circleXmark,
                  color: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  onTap: () => _handleCancelShift(context),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  title: 'Chấm công',
                  icon: FontAwesomeIcons.circleCheck,
                  color: AppColors.success,
                  bgColor: AppColors.success.withValues(alpha: 0.08),
                  onTap: () => _handleCheckIn(context),
                ),
                if (isForgot || isLate) ...[
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: 'Bổ sung chấm công',
                    icon: FontAwesomeIcons.calendarPlus,
                    color: Colors.orange.shade700,
                    bgColor: Colors.orange.shade50,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AttendanceAdjustmentScreen()),
                    ),
                  ),
                ],
              ],
            ] else if (showEmployeeSupplement && (isLate || isForgot || isNotYet)) ...[
              // Nhân viên xem ca của chính mình khi có vấn đề: chỉ có nút gửi yêu cầu Bổ sung chấm công
              const Text('Tùy chọn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              _buildActionButton(
                title: 'Bổ sung chấm công',
                icon: FontAwesomeIcons.calendarPlus,
                color: Colors.orange.shade700,
                bgColor: Colors.orange.shade50,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceAdjustmentScreen()),
                ),
              ),
            ],
            if (isOwnShift && isCheckedIn && !isLate && !canManage) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                child: const Row(children: [
                  FaIcon(FontAwesomeIcons.circleCheck, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(child: Text('Ca làm việc đã hoàn thành đúng giờ.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                ]),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelShift(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy ca'),
        content: Text('Bạn có chắc chắn muốn hủy ca "${shift.shiftName}" của ${staff.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy ca', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      if (shift.id.isNotEmpty) {
        await ShiftRepository().deleteShift(shift.id);
      }
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Đã hủy ca ${shift.shiftName} của ${staff.name}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hủy ca thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCheckIn(BuildContext context) async {
    try {
      final empId = staff.id.isNotEmpty ? staff.id : (staff.phone.isNotEmpty ? staff.phone : '1');
      await AttendanceRepository().checkIn(
        employeeId: empId,
        shiftId: shift.id,
      );
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã chấm công cho ${staff.name} - ${shift.shiftName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Chấm công thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _buildInfoRow(FaIconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        FaIcon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(width: 155, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.textPrimary))),
      ]),
    );
  }

  Widget _buildActionButton({required String title, required FaIconData icon, required Color color, required Color bgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(children: [
          FaIcon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))),
          FaIcon(FontAwesomeIcons.chevronRight, color: color.withValues(alpha: 0.6), size: 20),
        ]),
      ),
    );
  }
}
