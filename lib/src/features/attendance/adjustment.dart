import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
import '../leave_request/leave_repository.dart';
import '../schedule/shift_repository.dart';

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
  final LeaveRepository? leaveRepository;
  final ShiftRepository? shiftRepository;
  const AttendanceAdjustmentScreen({super.key, this.leaveRepository, this.shiftRepository});

  @override
  State<AttendanceAdjustmentScreen> createState() => _AttendanceAdjustmentScreenState();
}

class _AttendanceAdjustmentScreenState extends State<AttendanceAdjustmentScreen> {
  bool _isLoading = false;
  final List<AdjustmentItem> _items = [];
  List<ApiShiftModel> _shifts = [];
  String? _loadError;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = UserScope.currentUser(context)?.employeeId;
    if (_lastUserId != uid) {
      _lastUserId = uid;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final uid = UserScope.currentUser(context)?.employeeId;

    // Chọn dòng ca được phân công để gửi sourceShiftId chính xác.
    List<ApiShiftModel> shifts = _shifts;
    String? shiftError;
    try {
      if (uid == null || uid.isEmpty) {
        throw const ApiException('NO_EMPLOYEE', 'Tài khoản chưa gắn hồ sơ nhân sự', 400);
      }
      shifts = await (widget.shiftRepository ?? ShiftRepository()).getShifts(employeeId: uid);
    } catch (e) {
      shiftError = e is ApiException ? e.message : 'Không tải được lịch làm việc';
    }

    try {
      final requests = await (widget.leaveRepository ?? LeaveRepository()).getRequests(employeeId: uid);
      final supps = requests.where((r) => r.type == 'work_supplement').toList();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _items.clear();
          for (final r in supps) {
            // Dữ liệu đề nghị có cấu trúc; chỉ đọc content cho đơn cũ.
            final inMatch = RegExp(r'Vào:\s*([^,.]+)').firstMatch(r.content);
            final outMatch = RegExp(r'Ra:\s*([^,.]+)').firstMatch(r.content);
            final reasonMatch = RegExp(r'Lý do:\s*(.*)', dotAll: true).firstMatch(r.content);
            _items.add(AdjustmentItem(
              id: r.id,
              date: (r.createdAt ?? '').trim().isEmpty ? '—' : toVnDate(r.createdAt),
              shiftName: r.title,
              checkIn: r.requestedCheckIn != null ? toVnDateTime(r.requestedCheckIn) : inMatch?.group(1)?.trim() ?? '—',
              checkOut: r.requestedCheckOut != null ? toVnDateTime(r.requestedCheckOut) : outMatch?.group(1)?.trim() ?? '—',
              reason: reasonMatch != null ? reasonMatch.group(1)!.trim() : r.content,
              status: r.status,
              createdAt: r.createdAt ?? '',
            ));
          }
          _loadError = shiftError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _loadError = e is ApiException ? e.message : 'Không tải được danh sách yêu cầu';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text('❌ $message'),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  void _showCreateModal() {
    final shifts = _shifts.where((s) => !s.isCancelled).toList();
    if (shifts.isEmpty) {
      _showError('Chưa có ca được phân công để bổ sung chấm công.');
      return;
    }
    String selectedShift = shifts.first.id;
    String labelFor(ApiShiftModel shift) =>
        '${toVnDate(shift.workDate)} (${shift.timeLabel})';

    final inController = TextEditingController();
    final outController = TextEditingController();
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
              items: shifts
                  .map((shift) => DropdownMenuItem(
                        value: shift.id,
                        child: Text(labelFor(shift), style: const TextStyle(fontSize: 14)),
                      ))
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
                final inTime = inController.text.trim();
                final outTime = outController.text.trim();
                if (reason.isEmpty) {
                  _showError('Vui lòng nhập lý do giải trình');
                  return;
                }
                final hhmm = RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$');
                if (!hhmm.hasMatch(inTime) || !hhmm.hasMatch(outTime)) {
                  _showError('Nhập giờ vào/ra đúng định dạng HH:mm');
                  return;
                }
                final user = UserScope.currentUser(context);
                final empId = user?.employeeId ?? '';
                if (empId.isEmpty) {
                  _showError('Không xác định được nhân sự đang đăng nhập');
                  return;
                }
                final shift = shifts.firstWhere((s) => s.id == selectedShift);
                final workDate = parseVnDate(shift.workDate);
                if (workDate == null) {
                  _showError('Không xác định được ngày làm việc của ca');
                  return;
                }
                DateTime instant(String hm) {
                  final parts = hm.split(':').map(int.parse).toList();
                  var result = DateTime(workDate.year, workDate.month, workDate.day, parts[0], parts[1]);
                  final start = shift.scheduledStart.split(':').map(int.parse).toList();
                  if (shift.scheduledEnd.compareTo(shift.scheduledStart) < 0 &&
                      parts[0] * 60 + parts[1] < start[0] * 60 + start[1]) {
                    result = result.add(const Duration(days: 1));
                  }
                  return result;
                }
                final checkIn = instant(inTime);
                var checkOut = instant(outTime);
                if (checkOut.isBefore(checkIn)) {
                  if (shift.scheduledEnd.compareTo(shift.scheduledStart) >= 0) {
                    _showError('Giờ ra phải sau giờ vào');
                    return;
                  }
                  checkOut = checkOut.add(const Duration(days: 1));
                }
                if (checkIn.isAfter(DateTime.now()) || checkOut.isAfter(DateTime.now())) {
                  _showError('Không thể đề nghị chấm công trong tương lai');
                  return;
                }
                try {
                  await (widget.leaveRepository ?? LeaveRepository()).createRequest({
                    'type': 'work_supplement',
                    'title': 'Bổ sung chấm công: ${labelFor(shift)}',
                    'content': 'Vào: $inTime, Ra: $outTime. Lý do: $reason',
                    'employeeId': empId,
                    'sourceShiftId': shift.id,
                    'requestedCheckIn': checkIn.toUtc().toIso8601String(),
                    'requestedCheckOut': checkOut.toUtc().toIso8601String(),
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
                  _showError('Gửi yêu cầu thất bại: ${e is ApiException ? e.message : e}');
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
            if (_items.isEmpty && !_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    FaIcon(
                      _loadError != null ? FontAwesomeIcons.cloudBolt : FontAwesomeIcons.clockRotateLeft,
                      size: 36,
                      color: _loadError != null ? AppColors.error : Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loadError ?? 'Chưa có yêu cầu bổ sung công nào',
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
            Text('Gửi lúc: ${item.createdAt.trim().isEmpty ? '—' : toVnDateTime(item.createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
