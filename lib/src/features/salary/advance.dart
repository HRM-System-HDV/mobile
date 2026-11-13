import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
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
  String? _lastEmployeeId;
  String? _loadError;
  // Lỗi riêng của phần dữ liệu lương (ước tính hạn mức tạm ứng).
  String? _salaryError;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.error, content: Text('❌ $message')),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final empId = UserScope.currentUser(context)?.employeeId;
    if (_lastEmployeeId != empId) {
      _lastEmployeeId = empId;
      _fetchAdvances();
      _fetchSalary();
    }
  }

  Future<void> _fetchSalary() async {
    // Payslip thuộc payroll-service, khóa ngoại là UUID nhân sự, không phải
    // id tài khoản identity.
    final empId = UserScope.currentUser(context)?.employeeId;
    try {
      final payslips = await _salaryRepo.getPayslips(employeeId: empId);
      if (mounted) {
        setState(() {
          if (payslips.isEmpty) {
            _estimatedSalary = null;
          } else {
            // Lấy phiếu kỳ MỚI NHẤT (API trả desc theo ngày cấp) để ước
            // tính đúng kỳ, không dùng bản ghi bất kỳ trong danh sách.
            final p = payslips.first;
            final net = p.netSalary > 0 ? p.netSalary : p.baseSalary;
            _estimatedSalary = net > 0 ? net : null;
          }
          _salaryError = null;
        });
      }
    } catch (e) {
      // Lỗi mạng/403 không được hiện như "chưa có dữ liệu lương".
      if (mounted) {
        setState(() {
          _estimatedSalary = null;
          _salaryError = e is ApiException
              ? e.message
              : 'Không tải được dữ liệu lương. Kiểm tra kết nối hoặc thử lại.';
        });
      }
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
    final empId = UserScope.currentUser(context)?.employeeId;
    try {
      final list = await _leaveRepo.getRequests(employeeId: empId);
      if (mounted) {
        final apiRecords = list.where((m) => m.type == 'advance').map((m) {
          final amt = m.title.replaceFirst('Tạm ứng lương: ', '');
          return AdvanceRecord(
            id: m.id,
            amount: amt.isNotEmpty ? amt : '—',
            date: m.createdAt ?? '—',
            reason: m.content,
            status: m.status,
          );
        }).toList();

        setState(() {
          _records = apiRecords;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e is ApiException ? e.message : 'Không tải được danh sách tạm ứng';
        });
      }
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
                    ? 'Nhập số tiền muốn tạm ứng'
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
                // Backend chỉ nhận advanceAmount là chuỗi số nguyên dương, tối đa 15 chữ số.
                if (amount.isEmpty || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đầy đủ số tiền và lý do')),
                  );
                  return;
                }
                if (!RegExp(r'^[1-9]\d{0,14}$').hasMatch(amount)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('Số tiền ứng phải là số nguyên dương tối đa 15 chữ số, không có dấu chấm'),
                    ),
                  );
                  return;
                }
                final user = UserScope.currentUser(context);
                final empId = user?.employeeId ?? '';
                if (empId.isEmpty) {
                  _showError('Tài khoản chưa gắn hồ sơ nhân sự');
                  return;
                }

                try {
                  await _leaveRepo.createRequest({
                    'type': 'advance',
                    'title': 'Tạm ứng lương: $amount đ',
                    'content': reason,
                    'employeeId': empId,
                    'advanceAmount': amount,
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
                  _showError('Gửi yêu cầu tạm ứng thất bại: ${e is ApiException ? e.message : e}');
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
        _estimatedSalary != null ? _formatCurrency(_estimatedSalary!.toInt()) : '—';
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
                colors: [AppColors.successDark, AppColors.successGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.successDark.withValues(alpha: 0.3),
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
                    // Hệ thống không áp dụng hạn mức 50% cho đơn tạm ứng nên
                    // không được hiện con số hạn mức như thật.
                    const Text('Lương ước tính kỳ gần nhất:', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    Text(maxAdvanceText, style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Lỗi tải dữ liệu lương: không được hiện "—" như thể chưa có lương.
          if (_salaryError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF5D9B5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 18, color: Color(0xFFB25E09)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _salaryError!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A4B08)),
                    ),
                  ),
                  TextButton(onPressed: _fetchSalary, child: const Text('Thử lại')),
                ],
              ),
            ),

          if (_records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  FaIcon(
                    _loadError != null ? FontAwesomeIcons.cloudBolt : FontAwesomeIcons.handHoldingDollar,
                    size: 36,
                    color: _loadError != null ? AppColors.error : Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loadError ?? 'Chưa có yêu cầu tạm ứng nào',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loadError != null ? AppColors.error : AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Kéo xuống để thử lại.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
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
                Text(rec.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.successDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(isApproved ? 'Đã chi' : 'Chờ duyệt', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Ngày gửi: ${toVnDateTime(rec.date).isEmpty ? '—' : toVnDateTime(rec.date)} • Lý do: ${rec.reason}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
