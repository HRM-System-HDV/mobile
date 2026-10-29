import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../leave_request/leave_repository.dart';

class AdjustmentItem {
  final String id;
  final String date;
  final String shiftName;
  final String checkIn;
  final String checkOut;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String createdAt;

  const AdjustmentItem({
    required this.id,
    required this.date,
    required this.shiftName,
    required this.checkIn,
    required this.checkOut,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

class AttendanceAdjustmentScreen extends StatefulWidget {
  const AttendanceAdjustmentScreen({super.key});

  @override
  State<AttendanceAdjustmentScreen> createState() => _AttendanceAdjustmentScreenState();
}

class _AttendanceAdjustmentScreenState extends State<AttendanceAdjustmentScreen> {
  bool _isLoading = false;
  final List<AdjustmentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final requests = await LeaveRepository().getRequests();
      final supps = requests.where((r) => r.type == 'work_supplement').toList();
      if (mounted) {
        setState(() {
          _items.clear();
          for (final r in supps) {
            _items.add(AdjustmentItem(
              id: r.id,
              date: r.createdAt != null && r.createdAt!.length >= 10
                  ? r.createdAt!.substring(0, 10)
                  : 'Hôm nay',
              shiftName: r.title,
              checkIn: '--:--',
              checkOut: '--:--',
              reason: r.content,
              status: r.status,
              createdAt: r.createdAt ?? '',
            ));
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showCreateModal() {
    String selectedShift = 'Ca Sáng (08:00 - 12:00)';
    final inController = TextEditingController(text: '08:00');
    final outController = TextEditingController(text: '12:00');
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Đơn bổ sung / sửa chấm công',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text('Ca làm việc', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedShift,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: ['Ca Sáng (08:00 - 12:00)', 'Ca Chiều (12:00 - 18:00)', 'Ca Tối (18:00 - 22:30)']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (val) => selectedShift = val!,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giờ vào thực tế', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: inController,
                        decoration: InputDecoration(
                          hintText: 'HH:mm',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giờ ra thực tế', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: outController,
                        decoration: InputDecoration(
                          hintText: 'HH:mm',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Lý do giải trình', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Nhập chi tiết lý do quên chấm công hoặc lỗi mạng...',
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
                    const SnackBar(content: Text('Vui lòng nhập lý do giải trình')),
                  );
                  return;
                }
                final user = UserScope.currentUser(context);
                final empId = user?.id ?? '';
                if (empId.isEmpty) return;
                try {
                  await LeaveRepository().createRequest({
                    'type': 'work_supplement',
                    'title': 'Bổ sung chấm công: $selectedShift',
                    'content': 'Vào: ${inController.text.trim()}, Ra: ${outController.text.trim()}. Lý do: $reason',
                    'employeeId': empId,
                  });
                  if (modalCtx.mounted) {
                    Navigator.pop(modalCtx);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('✅ Đã gửi đơn bổ sung công! Quản lý sẽ xem xét duyệt.'),
                    ),
                  );
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('❌ Gửi yêu cầu thất bại: $e'),
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
              child: const Text('Gửi yêu cầu bổ sung', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bổ sung / sửa chấm công', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
        label: const Text('Tạo yêu cầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleCheck, color: Color(0xFF16A34A), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đơn giải trình hợp lệ sẽ được Quản lý chi nhánh duyệt và cập nhật công ca vào bảng lương tháng.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF15803D), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Danh sách yêu cầu bổ sung công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            if (_items.isEmpty && !_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    FaIcon(FontAwesomeIcons.clockRotateLeft, size: 36, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('Chưa có yêu cầu bổ sung công nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              )
            else
              ..._items.map((item) => _buildItemCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(AdjustmentItem item) {
    final bool isApproved = item.status == 'approved';
    final bool isPending = item.status == 'pending';

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
                Text(item.shiftName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isApproved ? AppColors.success : (isPending ? Colors.orange : Colors.red)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isApproved ? 'Đã duyệt' : (isPending ? 'Chờ duyệt' : 'Từ chối'),
                    style: TextStyle(
                      color: isApproved ? AppColors.success : (isPending ? Colors.orange : Colors.red),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ngày: ${item.date} • Vào: ${item.checkIn} - Ra: ${item.checkOut}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
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
