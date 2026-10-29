import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final list = await _leaveRepo.getRequests();
      if (mounted) {
        final apiItems = list.where((m) => m.type == 'leave').map((m) {
          final title = m.title.replaceFirst('Đơn xin nghỉ: ', '');
          String d = 'Hôm nay (Cả ngày)';
          String r = m.content;
          if (m.content.contains(' - Lý do: ')) {
            final parts = m.content.split(' - Lý do: ');
            d = parts.first;
            r = parts.last;
          }
          return LeaveRequestItem(
            id: m.id,
            leaveType: title.isNotEmpty ? title : 'Nghỉ phép',
            dates: d,
            reason: r,
            status: m.status,
            createdAt: m.createdAt ?? 'Vừa xong',
          );
        }).toList();

        setState(() {
          _requests = apiItems;
        });
      }
    } catch (_) {
      // API lỗi thì giữ nguyên danh sách hiện tại (rỗng) để hiện empty state.
    }
  }

  List<LeaveRequestItem> _requests = [];

  void _showCreateModal() {
    String selectedType = 'Nghỉ phép năm';
    String selectedDuration = 'Cả ngày';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
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
                  final dateStr = '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
                  final user = UserScope.currentUser(context);
                  final empId = user?.id ?? '';
                  if (empId.isEmpty) return;

                  try {
                    await _leaveRepo.createRequest({
                      'type': 'leave',
                      'title': 'Đơn xin nghỉ: $selectedType',
                      'content': '$dateStr ($selectedDuration) - Lý do: $reason',
                      'employeeId': empId,
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
                        content: Text('❌ Gửi đơn xin nghỉ thất bại: $e'),
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
                child: const Text('Gửi đơn xin nghỉ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          // Thẻ hạn mức phép năm
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phép năm còn lại', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('10 / 12 ngày', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Đã dùng 2 ngày • Hạn đến 31/12/${DateTime.now().year}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: FaIcon(FontAwesomeIcons.umbrellaBeach, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Lịch sử đơn nghỉ phép', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          if (_requests.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  FaIcon(FontAwesomeIcons.clipboardList, size: 36, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Chưa có đơn nghỉ phép nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
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
            Text('Gửi lúc: ${item.createdAt}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
