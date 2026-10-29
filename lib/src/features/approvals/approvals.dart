import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/branch_selector.dart';
import '../profile/employee_repository.dart';
import 'approval_repository.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum ShiftRequestType { swap, coverMe, dayOff, leave, adjustment, advance }
enum ShiftRequestStatus { pending, approved, rejected }

class ShiftRequest {
  final String id;
  final String staffName;
  final String staffRole;
  final String staffAvatar;
  final ShiftRequestType type;
  final String currentShift;
  final String? targetShift;
  final String? swapWithName;
  final String reason;
  final String submittedAt;
  ShiftRequestStatus status;

  ShiftRequest({
    required this.id,
    required this.staffName,
    required this.staffRole,
    required this.staffAvatar,
    required this.type,
    required this.currentShift,
    this.targetShift,
    this.swapWithName,
    required this.reason,
    required this.submittedAt,
    this.status = ShiftRequestStatus.pending,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ShiftRequestScreen extends StatefulWidget {
  const ShiftRequestScreen({super.key});

  @override
  State<ShiftRequestScreen> createState() => _ShiftRequestScreenState();
}

class _ShiftRequestScreenState extends State<ShiftRequestScreen>
    with SingleTickerProviderStateMixin {
  final ApprovalRepository _approvalRepo = ApprovalRepository();
  late TabController _tabController;
  List<ShiftRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final employees = await EmployeeRepository().getEmployees().catchError((_) => <Map<String, dynamic>>[]);
      final empMap = {for (final e in employees) e['id']?.toString() ?? '': e};

      final list = await _approvalRepo.getPending();
      if (mounted) {
        final apiRequests = list.map((m) {
          ShiftRequestType t = ShiftRequestType.leave;
          if (m.type == 'advance') {
            t = ShiftRequestType.advance;
          } else if (m.type == 'overtime') {
            t = ShiftRequestType.coverMe;
          } else if (m.type == 'shift_swap') {
            t = ShiftRequestType.swap;
          } else if (m.type == 'work_supplement') {
            t = ShiftRequestType.adjustment;
          }
          final emp = empMap[m.employeeId];
          final name = emp?['name']?.toString() ?? 'Nhân sự #${m.employeeId}';
          final role = emp?['role']?.toString() ?? (m.branchSlug ?? 'Nhân viên');
          final avatar = name.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();

          return ShiftRequest(
            id: m.id,
            staffName: name,
            staffRole: role,
            staffAvatar: avatar.isNotEmpty ? avatar : 'N',
            type: t,
            currentShift: m.title,
            reason: m.content,
            submittedAt: m.createdAt ?? 'Vừa xong',
            status: ShiftRequestStatus.pending,
          );
        }).toList();

        setState(() {
          // Chỉ dùng dữ liệu API thật; API rỗng thì thay toàn bộ bằng rỗng
          // để hiện empty state, không trộn/giữ mock.
          _requests = apiRequests;
        });
      }
    } catch (_) {
      // API lỗi thì giữ nguyên danh sách hiện tại (rỗng) để hiện empty state.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ShiftRequest> get _pendingRequests =>
      _requests.where((r) => r.status == ShiftRequestStatus.pending).toList();
  List<ShiftRequest> get _approvedRequests =>
      _requests.where((r) => r.status == ShiftRequestStatus.approved).toList();
  List<ShiftRequest> get _rejectedRequests =>
      _requests.where((r) => r.status == ShiftRequestStatus.rejected).toList();

  void _approve(ShiftRequest request) {
    _approvalRepo.approve(request.id).catchError((_) {});
    setState(() => request.status = ShiftRequestStatus.approved);
    final text = request.type == ShiftRequestType.swap
        ? '✅ Quản lý đã duyệt đồng ý hộ đổi ca cho ${request.staffName}'
        : '✅ Đã duyệt yêu cầu của ${request.staffName}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(text),
      ),
    );
  }

  void _reject(ShiftRequest request) {
    _approvalRepo.reject(request.id).catchError((_) {});
    setState(() => request.status = ShiftRequestStatus.rejected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text('❌ Đã từ chối yêu cầu của ${request.staffName}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phê duyệt yêu cầu nhân sự'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: const BackButton(),
        actions: const [
          BranchSelector(includeAll: false),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Chờ duyệt (${_pendingRequests.length})'),
                Tab(text: 'Đã duyệt (${_approvedRequests.length})'),
                Tab(text: 'Từ chối (${_rejectedRequests.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(_pendingRequests, showActions: true),
                _buildRequestList(_approvedRequests, showActions: false),
                _buildRequestList(_rejectedRequests, showActions: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<ShiftRequest> requests, {required bool showActions}) {
    return RefreshIndicator(
      onRefresh: _fetchPendingRequests,
      color: AppColors.primary,
      child: requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.inbox, size: 52, color: AppColors.textSecondary),
                      SizedBox(height: 10),
                      Text('Không có yêu cầu nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildRequestCard(requests[index], showActions: showActions),
            ),
    );
  }

  void _showRequestDetail(ShiftRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Color typeColor;
        String typeLabel;
        FaIconData typeIcon;
        switch (request.type) {
          case ShiftRequestType.swap:
            typeColor = Colors.blue;
            typeLabel = 'Đổi ca';
            typeIcon = FontAwesomeIcons.arrowsLeftRight;
            break;
          case ShiftRequestType.coverMe:
            typeColor = Colors.purple;
            typeLabel = 'Làm thay';
            typeIcon = FontAwesomeIcons.users;
            break;
          case ShiftRequestType.dayOff:
          case ShiftRequestType.leave:
            typeColor = Colors.orange;
            typeLabel = 'Nghỉ phép';
            typeIcon = FontAwesomeIcons.umbrellaBeach;
            break;
          case ShiftRequestType.adjustment:
            typeColor = Colors.teal;
            typeLabel = 'Bổ sung công';
            typeIcon = FontAwesomeIcons.penToSquare;
            break;
          case ShiftRequestType.advance:
            typeColor = Colors.indigo;
            typeLabel = 'Tạm ứng';
            typeIcon = FontAwesomeIcons.wallet;
            break;
        }

        final isPending = request.status == ShiftRequestStatus.pending;

        return Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết yêu cầu phê duyệt',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const FaIcon(FontAwesomeIcons.xmark, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 16),
              // Staff info
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      request.staffAvatar,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                          request.staffName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          request.staffRole,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(typeIcon, size: 14, color: typeColor),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Nội dung chi tiết
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(FontAwesomeIcons.calendarDay, 'Thời gian / Ca', request.currentShift),
                    if (request.targetShift != null)
                      _buildDetailRow(FontAwesomeIcons.arrowRightArrowLeft, 'Đổi sang', request.targetShift!),
                    if (request.swapWithName != null)
                      _buildDetailRow(FontAwesomeIcons.person, 'Người liên quan', request.swapWithName!),
                    const SizedBox(height: 4),
                    _buildDetailRow(FontAwesomeIcons.message, 'Lý do', request.reason),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.clock, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Gửi lúc: ${request.submittedAt}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 2 nút xác nhận: Từ chối & Phê duyệt
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _reject(request);
                        },
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                        label: const Text('Từ chối'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approve(request);
                        },
                        icon: const FaIcon(FontAwesomeIcons.check, size: 16),
                        label: Text(request.type == ShiftRequestType.swap ? 'Duyệt đồng ý hộ' : 'Phê duyệt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            request.status == ShiftRequestStatus.approved ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.xmark,
                            size: 16,
                            color: request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request.status == ShiftRequestStatus.approved ? 'Đã phê duyệt' : 'Đã từ chối',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(ShiftRequest request, {required bool showActions}) {
    Color typeColor;
    String typeLabel;
    FaIconData typeIcon;

    switch (request.type) {
      case ShiftRequestType.swap:
        typeColor = Colors.blue;
        typeLabel = 'Đổi ca';
        typeIcon = FontAwesomeIcons.arrowsLeftRight;
        break;
      case ShiftRequestType.coverMe:
        typeColor = Colors.purple;
        typeLabel = 'Làm thay';
        typeIcon = FontAwesomeIcons.users;
        break;
      case ShiftRequestType.dayOff:
      case ShiftRequestType.leave:
        typeColor = Colors.orange;
        typeLabel = 'Nghỉ phép';
        typeIcon = FontAwesomeIcons.umbrellaBeach;
        break;
      case ShiftRequestType.adjustment:
        typeColor = Colors.teal;
        typeLabel = 'Bổ sung công';
        typeIcon = FontAwesomeIcons.penToSquare;
        break;
      case ShiftRequestType.advance:
        typeColor = Colors.indigo;
        typeLabel = 'Tạm ứng';
        typeIcon = FontAwesomeIcons.wallet;
        break;
    }

    return InkWell(
      onTap: () => _showRequestDetail(request),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(request.staffAvatar,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.staffName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                        Text(request.staffRole,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(typeIcon, size: 12, color: typeColor),
                        const SizedBox(width: 4),
                        Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(FontAwesomeIcons.calendarDay, 'Nội dung', request.currentShift),
                  if (request.targetShift != null)
                    _buildDetailRow(FontAwesomeIcons.arrowRightArrowLeft, 'Đổi sang', request.targetShift!),
                  if (request.swapWithName != null)
                    _buildDetailRow(FontAwesomeIcons.person, 'Người liên quan', request.swapWithName!),
                  _buildDetailRow(FontAwesomeIcons.message, 'Lý do', request.reason),
                  const SizedBox(height: 4),
                  Text(
                    '🕐 Gửi lúc: ${request.submittedAt}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Action: Nút Chi tiết mở popup có 2 nút xác nhận
            const Divider(height: 18, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!showActions)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            request.status == ShiftRequestStatus.approved ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.xmark,
                            size: 13,
                            color: request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.status == ShiftRequestStatus.approved ? 'Đã duyệt' : 'Từ chối',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: request.status == ShiftRequestStatus.approved ? Colors.green : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  OutlinedButton.icon(
                    onPressed: () => _showRequestDetail(request),
                    icon: const FaIcon(FontAwesomeIcons.circleInfo, size: 14),
                    label: const Text('Chi tiết'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(FaIconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
