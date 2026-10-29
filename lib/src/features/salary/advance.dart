import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../leave_request/leave_repository.dart';
import 'salary_repository.dart';

class AdvanceRecord {
  final String id;
  final String amount;
  final String date;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'

  const AdvanceRecord({
    required this.id,
    required this.amount,
    required this.date,
    required this.reason,
    required this.status,
  });
}

class SalaryAdvanceScreen extends StatefulWidget {
  const SalaryAdvanceScreen({super.key});

  @override
  State<SalaryAdvanceScreen> createState() => _SalaryAdvanceScreenState();
}

class _SalaryAdvanceScreenState extends State<SalaryAdvanceScreen> {
  final LeaveRepository _leaveRepo = LeaveRepository();
  final SalaryRepository _salaryRepo = SalaryRepository();
  double? _estimatedSalary;

  @override
  void initState() {
    super.initState();
    _fetchAdvances();
    _fetchSalary();
  }

  Future<void> _fetchSalary() async {
    try {
      final payslips = await _salaryRepo.getPayslips();
      if (mounted) {
        setState(() {
          if (payslips.isEmpty) {
            _estimatedSalary = null;
          } else {
            final p = payslips.first;
            final net = p.netSalary > 0 ? p.netSalary : p.baseSalary;
            _estimatedSalary = net > 0 ? net : null;
          }
        });
      }
    } catch (_) {
      // Không có dữ liệu lương thì giữ null để hiển thị '—'.
    }
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join('')} đ';
  }

  Future<void> _fetchAdvances() async {
    try {
      final list = await _leaveRepo.getRequests();
      if (mounted) {
        final apiRecords = list.where((m) => m.type == 'advance').map((m) {
          final amt = m.title.replaceFirst('Tạm ứng lương: ', '');
          return AdvanceRecord(
            id: m.id,
            amount: amt.isNotEmpty ? amt : '1.000.000 đ',
            date: m.createdAt ?? 'Vừa xong',
            reason: m.content,
            status: m.status,
          );
        }).toList();

        setState(() {
          _records = apiRecords;
        });
      }
    } catch (_) {
      // API lỗi thì giữ nguyên danh sách hiện tại (rỗng) để hiện empty state.
    }
  }

  List<AdvanceRecord> _records = [];

  void _showAdvanceModal() {
    final amountController = TextEditingController();
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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            const Text('Tạo yêu cầu tạm ứng lương', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('Số tiền muốn tạm ứng (VNĐ)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _estimatedSalary != null
                    ? 'Tối đa ${_formatCurrency((_estimatedSalary! / 2).round())}'
                    : 'Nhập số tiền muốn tạm ứng',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: 'VNĐ',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Lý do tạm ứng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Nhập lý do chi tiết...',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () async {
                final amount = amountController.text.trim();
                final reason = reasonController.text.trim();
                if (amount.isEmpty || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đầy đủ số tiền và lý do')),
                  );
                  return;
                }
                final user = UserScope.currentUser(context);
                final empId = user?.id ?? '';
                if (empId.isEmpty) return;

                try {
                  await _leaveRepo.createRequest({
                    'type': 'advance',
                    'title': 'Tạm ứng lương: $amount đ',
                    'content': reason,
                    'employeeId': empId,
                  });
                  if (modalCtx.mounted) {
                    Navigator.pop(modalCtx);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('✅ Đã gửi yêu cầu tạm ứng lương thành công!'),
                    ),
                  );
                  _fetchAdvances();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('❌ Gửi yêu cầu tạm ứng thất bại: $e'),
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
              child: const Text('Gửi yêu cầu tạm ứng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String salaryText =
        _estimatedSalary != null ? _formatCurrency(_estimatedSalary!.toInt()) : '—';
    final String maxAdvanceText =
        _estimatedSalary != null ? _formatCurrency((_estimatedSalary! / 2).round()) : '—';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tạm ứng lương', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdvanceModal,
        backgroundColor: AppColors.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
        label: const Text('Tạo yêu cầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchAdvances();
          await _fetchSalary();
        },
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ hạn mức tạm ứng
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lương tạm tính tháng ${DateTime.now().month.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const FaIcon(FontAwesomeIcons.wallet, color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(salaryText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hạn mức được ứng tối đa (50%):', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    Text(maxAdvanceText, style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Lịch sử các đợt tạm ứng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          if (_records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  FaIcon(FontAwesomeIcons.handHoldingDollar, size: 36, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Chưa có yêu cầu tạm ứng nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                ],
              ),
            )
          else
            ..._records.map((rec) => _buildRecordCard(rec)),
        ],
      ),
    ),
  );
  }

  Widget _buildRecordCard(AdvanceRecord rec) {
    final bool isApproved = rec.status == 'approved';
    final Color color = isApproved ? AppColors.success : Colors.orange;

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
                Text(rec.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(isApproved ? 'Đã chi' : 'Chờ duyệt', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ngày gửi: ${rec.date} • Lý do: ${rec.reason}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
