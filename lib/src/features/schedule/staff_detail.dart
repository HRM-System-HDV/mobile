import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
import '../attendance/attendance_repository.dart';
import 'shift_repository.dart';
import 'general.dart';

/// Giờ công chỉ tính được khi có cả giờ vào và giờ ra thật.
double? _workedHours(String checkIn, String checkOut) {
  int? toMinutes(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final start = toMinutes(checkIn);
  final end = toMinutes(checkOut);
  if (start == null || end == null) return null;
  var diff = end - start;
  if (diff < 0) diff += 1440;
  return diff / 60;
}

class StaffGeneralShiftDetailScreen extends StatelessWidget {
  final StaffInShift staff;
  final GeneralShiftModel shift;
  final GeneralDayModel day;
  final int gracePeriodMinutes;

  /// Cấu hình "Thời gian cho phép chốt ra" (phút) đọc từ
  /// `GET /api/attendance/config`; backend mặc định 60 và 0 = tính năng tắt.
  final int checkoutWindowMinutes;

  /// Repository chấm công dùng cho hành động chốt ra ca bị bỏ qua. Cho phép
  /// truyền từ outside (test); để null thì màn tự tạo repository thật.
  final AttendanceRepository? attendance;

  const StaffGeneralShiftDetailScreen({
    super.key,
    required this.staff,
    required this.shift,
    required this.day,
    this.gracePeriodMinutes = 5,
    this.checkoutWindowMinutes = 60,
    this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final isNotYet = staff.checkInStatus == 'not_yet';
    final isCheckedIn = staff.checkInStatus == 'checked_in';
    final isInProgress = staff.checkInStatus == 'in_progress';

    // Ca bị bỏ qua vì quên chốt ra: backend chiếu status 'missed' (đã check-in,
    // chưa checkOut trong cửa sổ). checkOut vẫn null nên ca không được tính công.
    final isSkipped = staff.isSkippedCheckout;

    // Quên chấm công: Chưa chấm công mà ngày đã qua, HOẶC hôm nay đã qua giờ bắt đầu ca
    final isForgot = isNotYet && (() {
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
    if (isCheckedIn) {
      final startStr = shift.timeRange.split('-')[0].trim();
      final partsStart = startStr.split(':');
      final partsCheck = staff.checkInTime.split(':');
      if (partsStart.length == 2 && partsCheck.length == 2) {
        final sh = int.tryParse(partsStart[0]) ?? 0;
        final sm = int.tryParse(partsStart[1]) ?? 0;
        final ch = int.tryParse(partsCheck[0]) ?? 0;
        final cm = int.tryParse(partsCheck[1]) ?? 0;
        isLate = ch * 60 + cm - (sh * 60 + sm) > gracePeriodMinutes;
      }
    }

    String statusText;
    Color statusColor;
    if (isSkipped) {
      statusText = 'Bỏ qua ca';
      statusColor = Colors.red.shade700;
    } else if (isCheckedIn) {
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

    final checkIn = staff.checkInTime.isNotEmpty ? staff.checkInTime : 'Chưa chấm công';
    final checkOut = staff.checkOutTime.isNotEmpty
        ? staff.checkOutTime
        : (isSkipped
            ? 'Quá hạn chốt ra (đã bỏ qua)'
            : (isNotYet ? 'Chưa chấm công' : 'Chưa chấm công ra'));
    final worked = _workedHours(staff.checkInTime, staff.checkOutTime);
    final hours = worked == null
        ? '—'
        : '${worked.toStringAsFixed(1)} giờ';

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
            // Header gọn gàng, thoáng đãng
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: FaIcon(FontAwesomeIcons.clock, color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.shiftName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.dayOfWeek}, ${toVnDate(day.date)} • ${shift.timeRange}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
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
                _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày tính công', '${toVnDate(day.date)} (${day.dayOfWeek})'),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.user, 'Nhân viên', staff.name),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.briefcase, 'Ca làm việc', shift.shiftName),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.rightToBracket, 'Giờ check-in tính công', checkIn, valueColor: isForgot ? Colors.red.shade700 : null),
                _divider(),
                _buildInfoRow(FontAwesomeIcons.rightFromBracket, 'Giờ check-out tính công', checkOut, valueColor: (isForgot || isSkipped) ? Colors.red.shade700 : null),
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
              if (isSkipped) ...[
                // Ca bị bỏ qua vì quên chốt ra: admin/manager chốt lại bằng CHÍNH
                // hành động check-out thường (POST /api/attendance/checkout kèm
                // shiftId của ca, không phải "chấm công hộ"). Backend tự áp quyền
                // theo chi nhánh và trả message tiếng Việt khi bị từ chối (400/403).
                _buildActionButton(
                  title: 'Xác nhận Ra ca',
                  icon: FontAwesomeIcons.rightFromBracket,
                  color: AppColors.warningDark,
                  bgColor: AppColors.warningDark.withValues(alpha: 0.08),
                  onTap: () => _handleCheckOutSkipped(context),
                ),
              ] else if (isCheckedIn && !isLate) ...[
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
                    onTap: () => context.push('/attendance/adjustment'),
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
                onTap: () => context.push('/attendance/adjustment'),
              ),
            ],
            if (isOwnShift && isSkipped && !canManage) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                child: const Row(children: [
                  FaIcon(FontAwesomeIcons.circleExclamation, color: AppColors.errorDark),
                  SizedBox(width: 12),
                  Expanded(child: Text('Ca đã quá hạn chốt ra nên bị bỏ qua và không được tính công; bạn hãy liên hệ quản lý hoặc admin để chốt ca này.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                ]),
              ),
            ] else if (isOwnShift && isCheckedIn && !isLate && !canManage) ...[
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
      // `staff.shiftId` là id DÒNG CA THẬT (CA-xxxx) lấy từ GET /api/shifts.
      // `shift.id` là id khung ca mẫn nên backend không tìm thấy ca để xoá.
      if (staff.shiftId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ca chưa được phân cho nhân viên này nên không thể hủy'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      await ShiftRepository().deleteShift(staff.shiftId);
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
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Hủy ca thất bại'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleCheckIn(BuildContext context) async {
    try {
      if (staff.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không xác định được nhân viên để chấm công'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (staff.shiftId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ca chưa được phân cho nhân viên này nên không thể chấm công'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      await (attendance ?? AttendanceRepository()).checkIn(
        employeeId: staff.id,
        shiftId: staff.shiftId,
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
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Chấm công thất bại'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Chốt ra một ca bị bỏ qua (`attendanceState` = 'missed_checkout') bằng
  /// chính hành động check-out thường. `shiftId` là id dòng ca thật
  /// (`staff.shiftId` từ GET /api/shifts) — bắt buộc khi chốt cho nhân viên
  /// khác để backend đóng đúng bản ghi. Giờ ra do server tính, client không gửi.
  /// Thành công thì pop(true) để màn lịch chung tải lại, nhãn 'Bỏ qua ca' biến mất.
  /// Lỗi 400/403 thì hiện đúng `error.message` của backend (envelope { error }).
  Future<void> _handleCheckOutSkipped(BuildContext context) async {
    try {
      await (attendance ?? AttendanceRepository()).checkOut(
        employeeId: staff.id,
        shiftId: staff.shiftId,
      );
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã chốt ra ca ${shift.shiftName} của ${staff.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : '❌ Chốt ra ca thất bại'),
          backgroundColor: AppColors.error,
        ),
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
