import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
import 'leave_repository.dart';

class LeaveRequestItem {
  final String id;
  final String leaveType;
  final String dates;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String createdAt;

  const LeaveRequestItem({
    required this.id,
    required this.leaveType,
    required this.dates,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final LeaveRepository _leaveRepo = LeaveRepository();
  String? _loadedEmployeeId;
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empId = UserScope.currentUser(context)?.employeeId ?? '';
    if (_loadedEmployeeId != empId) {
      _loadedEmployeeId = empId;
      _fetchRequests();
    }
  }

  Future<void> _fetchRequests() async {
    try {
      // Đơn nghỉ phép keyed theo UUID nhân sự; id tài khoản identity không có
      // đơn nào nên backend sẽ trả rỗng.
      final empId = UserScope.currentUser(context)?.employeeId ?? '';
      if (empId.isEmpty) {
        if (mounted) {
          setState(() {
            _requests = [];
            _loadError = 'Tài khoản chưa gắn hồ sơ nhân sự.';
          });
        }
        return;
      }
      // Không lọc thì nhân viên xem được đơn nghỉ của cả chi nhánh.
      final list = await _leaveRepo.getRequests(employeeId: empId);
      if (mounted) {
        final apiItems = list.where((m) => m.type == 'leave').map((m) {
          final title = m.title.replaceFirst('Đơn xin nghỉ: ', '');
          String d = '—';
          String r = m.content;
          if (m.content.contains(' - Lý do: ')) {
            final parts = m.content.split(' - Lý do: ');
            d = parts.first;
            r = parts.last;
          }
          return LeaveRequestItem(
            id: m.id,
            leaveType: title.isNotEmpty ? title : '—',
            dates: d,
            reason: r,
            status: m.status,
            createdAt: m.createdAt ?? '—',
          );
        }).toList();

        setState(() {
          _requests = apiItems;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e is ApiException ? e.message : 'Không tải được đơn nghỉ phép');
      }
    }
  }

  List<LeaveRequestItem> _requests = [];

  /// Backend (`contentFields.request`) chỉ nhận ngày nghỉ dạng ISO YYYY-MM-DD.
  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.calendarDay, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  vnDate(value),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Text('Đổi ngày', style: TextStyle(fontSize: 12.5, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateModal() {
    String selectedType = 'Nghỉ phép năm';
    String selectedDuration = 'Cả ngày';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime selectedEndDate = DateTime.now().add(const Duration(days: 1));
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              const Text(
                'Tạo đơn đăng ký nghỉ phép',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text('Loại nghỉ phép', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ['Nghỉ phép năm', 'Nghỉ ốm', 'Việc riêng không lương', 'Nghỉ chế độ']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedType = val!),
              ),
              const SizedBox(height: 12),
              const Text('Phạm vi nghỉ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedDuration,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ['Cả ngày', 'Ca Sáng (08:00 - 12:00)', 'Ca Chiều (12:00 - 18:00)', 'Ca Tối (18:00 - 22:00)']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedDuration = val!),
              ),
              const SizedBox(height: 12),
              _buildDateField(
                label: 'Ngày nghỉ',
                value: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onPicked: (d) => setModalState(() {
                  selectedDate = d;
                  if (selectedEndDate.isBefore(d)) selectedEndDate = d;
                }),
              ),
              const SizedBox(height: 12),
              _buildDateField(
                label: 'Đến ngày',
                value: selectedEndDate,
                firstDate: selectedDate,
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onPicked: (d) => setModalState(() => selectedEndDate = d),
              ),
              const SizedBox(height: 12),
              const Text('Lý do nghỉ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Nhập chi tiết lý do xin nghỉ...',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập lý do xin nghỉ')),
                    );
                    return;
                  }
                  final dateStr = selectedEndDate == selectedDate
                      ? vnDate(selectedDate)
                      : '${vnDate(selectedDate)} - ${vnDate(selectedEndDate)}';
                  final user = UserScope.currentUser(context);
                  final empId = user?.employeeId ?? '';
                  if (empId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('❌ Tài khoản chưa gắn hồ sơ nhân sự'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _leaveRepo.createRequest({
                      'type': 'leave',
                      'title': 'Đơn xin nghỉ: $selectedType',
                      'content': '$dateStr ($selectedDuration) - Lý do: $reason',
                      'employeeId': empId,
                      'leaveStartDate': _isoDate(selectedDate),
                      'leaveEndDate': _isoDate(selectedEndDate),
                    });
                    if (modalCtx.mounted) {
                      Navigator.pop(modalCtx);
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('✅ Đã gửi đơn xin nghỉ phép thành công!'),
                      ),
                    );
                    _fetchRequests();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('❌ Gửi đơn xin nghỉ thất bại: ${e is ApiException ? e.message : e}'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Gửi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đăng ký nghỉ phép', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
        label: const Text('Tạo đơn nghỉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_requests.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  FaIcon(
                    _loadError != null ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.clipboardList,
                    size: 36,
                    color: _loadError != null ? AppColors.error : Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loadError ?? 'Chưa có đơn nghỉ phép nào',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loadError != null ? AppColors.error : AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 6),
                    const Text('Kéo xuống để thử lại.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ],
              ),
            )
          else
            ..._requests.map((r) => _buildRequestCard(r)),
        ],
      ),
    ),
  );
  }

  Widget _buildRequestCard(LeaveRequestItem item) {
    final Color statusColor;
    final String statusText;
    switch (item.status) {
      case 'approved':
        statusColor = AppColors.success;
        statusText = 'Đã duyệt';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Từ chối';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'Chờ duyệt';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.leaveType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.calendar, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(item.dates, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Lý do: ${item.reason}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('Gửi lúc: ${item.createdAt.trim().isEmpty || item.createdAt == '—' ? '—' : toVnDateTime(item.createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
