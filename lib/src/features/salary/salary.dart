import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/payslip.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../attendance/attendance_repository.dart';
import '../leave_request/leave_repository.dart';
import '../schedule/shift_repository.dart';
import 'salary_repository.dart';

class WorkLogItem {
  final String date;
  final String checkIn;
  final String checkOut;
  final double? hours;
  final int? basePay;
  final String status;

  const WorkLogItem({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.hours,
    required this.basePay,
    required this.status,
  });
}

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  late String _selectedMonth;
  late List<String> _months;
  final List<WorkLogItem> _workLogs = [];
  int _assignedShiftCount = 0;
  double _assignedHours = 0.0;
  int _workedShiftCount = 0;
  double _workedHours = 0.0;

  final SalaryRepository _salaryRepository = SalaryRepository();
  List<PayslipModel> _apiPayslips = const [];
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final cur = 'Tháng ${now.month.toString().padLeft(2, '0')}/${now.year}';
    final prev1 = DateTime(now.year, now.month - 1, 1);
    final m1 = 'Tháng ${prev1.month.toString().padLeft(2, '0')}/${prev1.year}';
    final prev2 = DateTime(now.year, now.month - 2, 1);
    final m2 = 'Tháng ${prev2.month.toString().padLeft(2, '0')}/${prev2.year}';
    _selectedMonth = '$cur (Hiện tại)';
    _months = ['$cur (Hiện tại)', m1, m2];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = UserScope.currentUser(context)?.id;
    if (_lastUserId != uid) {
      _lastUserId = uid;
      _loadPayslips();
    }
  }

  String _monthQuery(String label) {
    final m = RegExp(r'(\d{2})/(\d{4})').firstMatch(label);
    if (m != null) {
      return '${m.group(1)}-${m.group(2)}';
    }
    return '';
  }

  PayslipModel? get _currentPayslip {
    final q = _monthQuery(_selectedMonth);
    for (final p in _apiPayslips) {
      if (p.month == q) return p;
    }
    return _apiPayslips.isNotEmpty ? _apiPayslips.first : null;
  }

  Future<void> _loadPayslips() async {
    final user = UserScope.currentUser(context);
    final uid = user?.id;
    final q = _monthQuery(_selectedMonth);
    Object? firstError;
    try {
      final items = await _salaryRepository.getPayslips(
        employeeId: uid,
        month: q.isNotEmpty ? q : null,
      );
      if (mounted) setState(() => _apiPayslips = items);
    } catch (e) {
      firstError ??= e;
      if (mounted) setState(() => _apiPayslips = []);
    }

    // Tải danh sách ca làm việc để tính số ca/giờ được phân công
    try {
      final allShifts = await ShiftRepository().getShifts(employeeId: uid);
      int shiftCount = 0;
      double hoursCount = 0.0;
      bool hoursUnknown = false;
      for (final s in allShifts) {
        // Lọc theo tháng đang chọn nếu có
        if (q.isNotEmpty && s.date.contains('-')) {
          final parts = s.date.split('-');
          if (parts.length >= 3) {
            final shiftMonth = '${parts[1]}-${parts[2]}';
            if (shiftMonth != q) continue;
          }
        }
        shiftCount++;
        final pStart = s.scheduledStart.split(':');
        final pEnd = s.scheduledEnd.split(':');
        if (pStart.length == 2 && pEnd.length == 2) {
          final m1 = (int.tryParse(pStart[0]) ?? 0) * 60 + (int.tryParse(pStart[1]) ?? 0);
          final m2 = (int.tryParse(pEnd[0]) ?? 0) * 60 + (int.tryParse(pEnd[1]) ?? 0);
          if (m2 > m1) {
            hoursCount += (m2 - m1) / 60.0;
          } else {
            hoursUnknown = true;
          }
        } else {
          hoursUnknown = true;
        }
      }
      if (mounted) {
        setState(() {
          _assignedShiftCount = shiftCount;
          // Có ca không xác định được giờ thì không hiển thị tổng thiếu chính xác.
          _assignedHours = hoursUnknown ? 0.0 : hoursCount;
        });
      }
    } catch (e) {
      firstError ??= e;
      if (mounted) {
        setState(() {
          _assignedShiftCount = 0;
          _assignedHours = 0.0;
        });
      }
    }

    try {
      final atts = await AttendanceRepository().getAttendance(employeeId: uid);
      final logs = <WorkLogItem>[];
      int doneShifts = 0;
      double doneHours = 0.0;
      bool hoursUnknown = false;
      for (final a in atts) {
        // Lọc theo tháng
        if (q.isNotEmpty && a.date.contains('-')) {
          final parts = a.date.split('-');
          if (parts.length >= 3) {
            final attMonth = '${parts[1]}-${parts[2]}';
            if (attMonth != q) continue;
          }
        }
        final date = a.date.isNotEmpty ? a.date : '—';
        final checkIn = a.checkIn ?? '--:--';
        final checkOut = a.checkOut ?? '--:--';
        double? hours;
        if (a.checkIn != null && a.checkOut != null) {
          final pIn = a.checkIn!.split(':');
          final pOut = a.checkOut!.split(':');
          if (pIn.length == 2 && pOut.length == 2) {
            final mIn = (int.tryParse(pIn[0]) ?? 0) * 60 + (int.tryParse(pIn[1]) ?? 0);
            final mOut = (int.tryParse(pOut[0]) ?? 0) * 60 + (int.tryParse(pOut[1]) ?? 0);
            if (mOut > mIn) hours = (mOut - mIn) / 60.0;
          }
        }
        doneShifts++;
        if (hours != null) {
          doneHours += hours;
        } else {
          hoursUnknown = true;
        }

        final status = a.status == 'late'
            ? 'Đi trễ'
            : (a.status == 'absent' ? 'Vắng mặt' : 'Đúng giờ');
        logs.add(WorkLogItem(
          date: date,
          checkIn: checkIn,
          checkOut: checkOut,
          hours: hours != null ? double.parse(hours.toStringAsFixed(1)) : null,
          // API chấm công không trả tiền công từng ca nên không tự tính.
          basePay: null,
          status: status,
        ));
      }
      if (mounted) {
        setState(() {
          _workLogs.clear();
          _workLogs.addAll(logs);
          _workedShiftCount = doneShifts;
          _workedHours = hoursUnknown ? 0.0 : doneHours;
        });
      }
    } catch (e) {
      firstError ??= e;
      if (mounted) {
        setState(() {
          _workLogs.clear();
          _workedShiftCount = 0;
          _workedHours = 0.0;
        });
      }
    }

    if (firstError != null) {
      _showError('Không tải đủ dữ liệu lương: '
          '${firstError is ApiException ? firstError.message : firstError}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text('❌ $message'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatCurrency(int amount) {    final str = amount.toString();
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

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserScope.isAdmin(context);
    final bool canManage = UserScope.canManage(context);
    final String pageTitle = isAdmin
        ? 'Phiếu lương toàn công ty'
        : (canManage ? 'Bảng công & Lương chi nhánh' : 'Kỳ lương & Phiếu lương cá nhân');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayslips,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Month Picker Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _months.firstWhere(
                    (m) => m.startsWith(_selectedMonth),
                    orElse: () => _months.first,
                  ),
                  icon: const FaIcon(FontAwesomeIcons.chevronDown, color: AppColors.primary),
                  items: _months.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(
                        'Kỳ: $m',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final parts = val.split(' ');
                      setState(() {
                        _selectedMonth = '${parts[0]} ${parts[1]}';
                      });
                      _loadPayslips();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Main Net Salary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TẠM TÍNH THỰC LĨNH',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPayslip != null ? _formatCurrency(_currentPayslip!.netSalary.toInt()) : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentPayslip != null
                            ? 'Trạng thái: ${_currentPayslip!.status}'
                            : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text('Kỳ: ${_monthQuery(_selectedMonth)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Salary Breakdown
            _buildSectionHeader('Chi tiết các khoản thu nhập'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSalaryRow('Lương cơ bản', _currentPayslip != null ? _formatCurrency(_currentPayslip!.baseSalary.toInt()) : '—'),
                  const Divider(height: 16),
                  _buildSalaryRow('Số giờ làm việc được phân công', _assignedHours > 0 ? '${_assignedHours.toStringAsFixed(1)} giờ' : '—'),
                  const Divider(height: 16),
                  _buildSalaryRow('Số ca làm việc được phân công', _assignedShiftCount > 0 ? '$_assignedShiftCount ca' : '—'),
                  const Divider(height: 16),
                  _buildSalaryRow('Số giờ làm việc tính lương', _workedHours > 0 ? '${_workedHours.toStringAsFixed(1)} giờ' : '—'),
                  const Divider(height: 16),
                  _buildSalaryRow('Số ca làm việc tính lương', _workedShiftCount > 0 ? '$_workedShiftCount ca' : '—'),
                  const Divider(height: 16),
                  _buildSalaryRow('Khấu trừ', _currentPayslip != null ? _formatCurrency(_currentPayslip!.totalPenalty.toInt()) : '—', isNegative: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Daily Work Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Nhật ký chấm công'),
                Text(
                  '${_workLogs.length} ca làm',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _workLogs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28, horizontal: 14),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_note_outlined, size: 40, color: AppColors.textSecondary),
                            SizedBox(height: 10),
                            Text(
                              'Chưa có dữ liệu chấm công',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dữ liệu ca làm sẽ hiện khi API chấm công sẵn sàng',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _workLogs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _workLogs[index];
                  bool isWarning = log.status.contains('Trễ');

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log.date,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              log.basePay != null ? _formatCurrency(log.basePay!) : '—',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Vào: ${log.checkIn} - Ra: ${log.checkOut}${log.hours != null ? ' (${log.hours}h)' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isWarning
                                    ? Colors.orange.withValues(alpha: 0.12)
                                    : AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isWarning ? Colors.orange.shade800 : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Khiếu nại phiếu lương
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showSupportSheet();
                },
                icon: const FaIcon(FontAwesomeIcons.triangleExclamation, size: 18),
                label: const Text(
                  'Khiếu nại phiếu lương',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSalaryRow(String label, String amount, {bool isPositive = false, bool isNegative = false}) {
    Color amountColor = AppColors.textPrimary;
    if (isPositive) amountColor = const Color(0xFF10B981);
    if (isNegative) amountColor = AppColors.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ],
    );
  }

  void _showSupportSheet() {
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Khiếu nại công / Lương', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Mô tả vấn đề',
                hintText: 'Ví dụ: Ca ngày hôm qua bị ghi nhận trễ do lỗi mạng...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final content = descCtrl.text.trim();
                if (content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập mô tả vấn đề')),
                  );
                  return;
                }
                final user = UserScope.currentUser(context);
                final uid = user?.id ?? '';
                if (uid.isEmpty) return;
                try {
                  await LeaveRepository().createRequest({
                    'type': 'other',
                    'title': 'Khiếu nại phiếu lương: $_selectedMonth',
                    'content': content,
                    'employeeId': uid,
                  });
                  if (sheetCtx.mounted) {
                    Navigator.pop(sheetCtx);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('✅ Đã gửi phản ánh tới phòng Nhân sự!'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('❌ Gửi phản ánh thất bại: $e'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Gửi phản ánh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
