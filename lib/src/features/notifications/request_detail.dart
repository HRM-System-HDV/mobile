import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../approvals/approval_repository.dart';

enum ShiftRequestStatus { pending, accepted, rejected }

class ShiftRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final String title;
  final String senderName;
  final String senderRole;
  final String senderPhone;
  final String requestType; // 'cover' (Nhờ làm thay) hoặc 'swap' (Đổi ca)
  final String requestTime;

  // Ca của đồng nghiệp (bạn sẽ nhận)
  final String shiftName;
  final String shiftTime;
  final String shiftHours;
  final String shiftDate;
  final String branch;
  final String shiftRole;

  // Ca của bạn (dành cho swap - bạn sẽ nhượng lại)
  final String? swapShiftName;
  final String? swapShiftTime;
  final String? swapShiftHours;
  final String? swapShiftDate;
  final String? swapShiftBranch;
  final String? swapShiftRole;

  final String reason;
  final ShiftRequestStatus initialStatus;
  final Function(ShiftRequestStatus newStatus)? onStatusChanged;

  const ShiftRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.title,
    required this.senderName,
    required this.senderRole,
    this.senderPhone = '',
    this.requestType = 'cover',
    this.requestTime = '25 phút trước',
    required this.shiftName,
    required this.shiftTime,
    this.shiftHours = '5.0 giờ',
    required this.shiftDate,
    required this.branch,
    this.shiftRole = 'Thu ngân',
    this.swapShiftName,
    this.swapShiftTime,
    this.swapShiftHours = '5.0 giờ',
    this.swapShiftDate,
    this.swapShiftBranch,
    this.swapShiftRole = 'Phục vụ',
    required this.reason,
    this.initialStatus = ShiftRequestStatus.pending,
    this.onStatusChanged,
  });

  @override
  State<ShiftRequestDetailScreen> createState() => _ShiftRequestDetailScreenState();
}

class _ShiftRequestDetailScreenState extends State<ShiftRequestDetailScreen> {
  late ShiftRequestStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  void _handleResponse(ShiftRequestStatus newStatus) {
    if (newStatus == ShiftRequestStatus.accepted) {
      ApprovalRepository().approve(widget.requestId).catchError((_) {});
    } else if (newStatus == ShiftRequestStatus.rejected) {
      ApprovalRepository().reject(widget.requestId).catchError((_) {});
    }
    setState(() => _status = newStatus);
    if (widget.onStatusChanged != null) {
      widget.onStatusChanged!(newStatus);
    }

    final isAccept = newStatus == ShiftRequestStatus.accepted;
    final message = isAccept
        ? (widget.requestType == 'cover'
            ? '✅ Bạn đã chấp nhận làm thay ca cho ${widget.senderName}!'
            : '✅ Bạn đã chấp nhận đổi ca với ${widget.senderName}!')
        : '❌ Bạn đã từ chối yêu cầu từ ${widget.senderName}.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isAccept ? AppColors.success : AppColors.error,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCover = widget.requestType == 'cover';

    final Color statusColor = _status == ShiftRequestStatus.accepted
        ? AppColors.success
        : (_status == ShiftRequestStatus.rejected
            ? AppColors.error
            : Colors.amber.shade800);

    final String statusText = _status == ShiftRequestStatus.accepted
        ? 'Đã chấp nhận'
        : (_status == ShiftRequestStatus.rejected
            ? 'Đã từ chối'
            : 'Chờ phản hồi');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isCover ? 'Chi tiết nhờ làm thay' : 'Chi tiết yêu cầu đổi ca',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, _status),
          tooltip: 'Quay lại',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header tổng quan ca làm việc ──────────────────────────
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
                          widget.shiftName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.shiftDate} • ${widget.shiftTime}',
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

            // ── Thông tin ca làm việc cần nhận / đổi ──────────────────
            Text(
              isCover ? 'Thông tin ca nhờ làm thay' : 'Ca bạn sẽ nhận vào',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
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
              child: Column(
                children: [
                  _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày làm việc', widget.shiftDate),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.clock, 'Khung giờ ca', widget.shiftTime),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ làm việc', widget.shiftHours),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.store, 'Chi nhánh', widget.branch),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.idCard, 'Vị trí công việc', widget.shiftRole),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.user, 'Người gửi yêu cầu', '${widget.senderName} (${widget.senderRole})',
                      valueColor: AppColors.primary),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.phone, 'Số điện thoại',
                      widget.senderPhone.isEmpty ? 'Chưa cập nhật' : widget.senderPhone),
                  _divider(),
                  _buildInfoRow(
                    FontAwesomeIcons.tag,
                    'Loại yêu cầu',
                    isCover ? 'Nhờ làm thay' : 'Đổi ca làm việc',
                    valueColor: isCover ? Colors.orange.shade800 : AppColors.primary,
                  ),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.flag, 'Trạng thái', statusText, valueColor: statusColor),
                ],
              ),
            ),

            // ── Nếu là Đổi ca: Thẻ ca đối ứng (nhượng lại) ───────────
            if (!isCover) ...[
              const SizedBox(height: 20),
              const Text(
                'Ca đổi của bạn (nhượng lại)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                child: Column(
                  children: [
                    _buildInfoRow(FontAwesomeIcons.briefcase, 'Ca làm việc', widget.swapShiftName ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày làm việc', widget.swapShiftDate ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.clock, 'Khung giờ ca', widget.swapShiftTime ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ làm việc', widget.swapShiftHours ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.store, 'Chi nhánh', widget.swapShiftBranch ?? widget.branch),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.idCard, 'Vị trí công việc', widget.swapShiftRole ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.user, 'Người phụ trách', UserScope.currentUser(context)?.name != null ? '${UserScope.currentUser(context)!.name} (Bạn)' : 'Bạn'),
                  ],
                ),
              ),
            ],

            // ── Lý do / Lời nhắn ─────────────────────────────────────
            const SizedBox(height: 20),
            const Text(
              'Lý do / Lời nhắn',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                  const FaIcon(FontAwesomeIcons.quoteLeft, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.reason.isNotEmpty ? widget.reason : 'Không có ghi chú thêm.',
                      style: const TextStyle(fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
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
            width: 150,
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

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _status == ShiftRequestStatus.pending
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleResponse(ShiftRequestStatus.rejected),
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 18, color: AppColors.error),
                        label: const Text(
                          'Từ chối',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleResponse(ShiftRequestStatus.accepted),
                        icon: const FaIcon(FontAwesomeIcons.check, size: 18, color: Colors.white),
                        label: const Text(
                          'Chấp nhận',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _status == ShiftRequestStatus.accepted ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _status == ShiftRequestStatus.accepted ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      _status == ShiftRequestStatus.accepted ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
                      color: _status == ShiftRequestStatus.accepted ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _status == ShiftRequestStatus.accepted ? 'Bạn đã chấp nhận yêu cầu này.' : 'Bạn đã từ chối yêu cầu này.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: _status == ShiftRequestStatus.accepted ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
