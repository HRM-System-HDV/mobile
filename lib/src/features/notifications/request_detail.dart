import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
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
    this.requestTime = '',
    required this.shiftName,
    required this.shiftTime,
    this.shiftHours = '',
    required this.shiftDate,
    required this.branch,
    this.shiftRole = '',
    this.swapShiftName,
    this.swapShiftTime,
    this.swapShiftHours,
    this.swapShiftDate,
    this.swapShiftBranch,
    this.swapShiftRole,
    required this.reason,
    this.initialStatus = ShiftRequestStatus.pending,
    this.onStatusChanged,
  });

  @override
  State<ShiftRequestDetailScreen> createState() => _ShiftRequestDetailScreenState();
}

class _ShiftRequestDetailScreenState extends State<ShiftRequestDetailScreen> {
  late ShiftRequestStatus _status;

  /// `false` = đơn thuộc chế độ quản lý duyệt, nhân viên được nhờ KHÔNG phản hồi
  /// được (integration-service chặn 403). `null` = chưa đọc được đơn từ API.
  bool? _peerCanRespond;
  String? _reason;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    if (widget.requestId.isNotEmpty) {
      _loadShiftSwapMode();
    }
  }

  /// Lấy `shiftSwapMode` của chính đơn (bản chụp lúc tạo) thay vì suy từ cấu hình
  /// chấm công toàn cục — cấu hình có thể đã đổi sau khi gửi đơn.
  Future<void> _loadShiftSwapMode() async {
    try {
      final row = await ApprovalRepository().get(widget.requestId);
      if (!mounted) return;
      final me = UserScope.currentUser(context);
      setState(() {
        _peerCanRespond = row.shiftSwapMode == 'mutual_acceptance' && row.targetEmployeeId == me?.employeeId;
        _status = row.status == 'approved' ? ShiftRequestStatus.accepted
            : row.status == 'rejected' ? ShiftRequestStatus.rejected : ShiftRequestStatus.pending;
        _reason = row.content;
      });
    } catch (_) {
      // Không đọc được đơn thì chưa cho phép phản hồi.
    }
  }

  Future<void> _handleResponse(ShiftRequestStatus newStatus) async {
    try {
      await ApprovalRepository().respond(
        widget.requestId,
        accept: newStatus == ShiftRequestStatus.accepted,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('❌ ${e.message}')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _status = newStatus);
    if (widget.onStatusChanged != null) {
      widget.onStatusChanged!(newStatus);
    }

    final isAccept = newStatus == ShiftRequestStatus.accepted;
    // Chấp nhận là lệnh đổi lịch phân ca thật (integration-service gọi
    // /api/shifts/swap trước khi ghi approved), nên báo rõ kết quả.
    final message = isAccept
        ? (widget.requestType == 'cover'
            ? '✅ Bạn đã nhận làm thay ca cho ${widget.senderName} — lịch phân ca đã cập nhật!'
            : '✅ Bạn đã đổi ca với ${widget.senderName} — lịch phân ca của hai bạn đã đổi!')
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
                          '${toVnDate(widget.shiftDate)} • ${widget.shiftTime}',
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
                  _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày làm việc',
                      toVnDate(widget.shiftDate).isEmpty ? '—' : toVnDate(widget.shiftDate)),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.clock, 'Khung giờ ca', widget.shiftTime),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ làm việc', widget.shiftHours.isEmpty ? '—' : widget.shiftHours),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.store, 'Chi nhánh', _branchLabel(widget.branch)),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.idCard, 'Vị trí công việc', widget.shiftRole.isEmpty ? '—' : widget.shiftRole),
                  _divider(),
                  _buildInfoRow(FontAwesomeIcons.user, 'Người gửi yêu cầu',
                      widget.senderRole.isEmpty ? widget.senderName : '${widget.senderName} (${widget.senderRole})',
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
                    _buildInfoRow(FontAwesomeIcons.calendarDay, 'Ngày làm việc',
                        toVnDate(widget.swapShiftDate).isEmpty ? '—' : toVnDate(widget.swapShiftDate)),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.clock, 'Khung giờ ca', widget.swapShiftTime ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.stopwatch, 'Số giờ làm việc', widget.swapShiftHours ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.store, 'Chi nhánh', _branchLabel(widget.swapShiftBranch ?? widget.branch)),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.idCard, 'Vị trí công việc', widget.swapShiftRole ?? '—'),
                    _divider(),
                    _buildInfoRow(FontAwesomeIcons.user, 'Người phụ trách', UserScope.currentUser(context)?.name != null ? '${UserScope.currentUser(context)!.name} (Bạn)' : 'Bạn'),
                  ],
                ),
              ),
            ],

            // ── Lý do / Lời nhắn (chỉ hiển thị khi không phải cover hoặc có lý do cụ thể) ──
            if ((_reason ?? widget.reason).isNotEmpty) ...[
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
                        _reason ?? widget.reason,
                        style: const TextStyle(fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
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
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  /// branchId là UUID (thiết kế lại 13-14/11 đã bỏ slug): phân giải qua cache branch
  /// nạp lúc đăng nhập; không có trong cache thì giữ nguyên id (không bịa tên).
  String _branchLabel(String raw) {
    if (raw.trim().isEmpty) return '—';
    final name = branchById(raw.trim()).name;
    return name.isEmpty ? raw : name;
  }

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
    // BE chặn nhân viên đích accept/decline khi đơn ở chế độ manager_approval
    // (403 "Bạn không có quyền phản hồi đơn này") nên không vẽ 2 nút phản hồi.
    final bool awaitingManager = _status == ShiftRequestStatus.pending;
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
        child: _status == ShiftRequestStatus.pending && _peerCanRespond == true
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
            : awaitingManager
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.clock, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bạn chỉ có thể phản hồi khi là người nhận đơn đang chờ xác nhận. Đơn ở chế độ quản lý duyệt cần được quản lý xử lý.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
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
