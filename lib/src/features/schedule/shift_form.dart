import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
import '../leave_request/leave_repository.dart';
import '../profile/employee_repository.dart';
import 'shift_repository.dart';
import 'schedule.dart';

enum ShiftActionType {
  cover, // Nhờ làm thay (Pass ca cho 1 nhân viên cụ thể)
  swap,  // Đổi ca làm việc (Chọn ngày -> Chọn ca -> Chọn người đổi)
  leave, // Xin nghỉ ca (Gửi admin)
}

class ShiftStaffMember {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String shiftId;

  const ShiftStaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.shiftId = '',
  });

  String get displayName => role.isEmpty ? name : '$name ($role)';
}

class ShiftActionFormScreen extends StatefulWidget {
  final ShiftDetail shift;
  final String date;
  final String dayOfWeek;
  final ShiftActionType actionType;

  const ShiftActionFormScreen({
    super.key,
    required this.shift,
    required this.date,
    required this.dayOfWeek,
    required this.actionType,
  });

  @override
  State<ShiftActionFormScreen> createState() => _ShiftActionFormScreenState();
}

class _ShiftActionFormScreenState extends State<ShiftActionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  // Nhờ làm thay — tải từ /api/employees, rỗng thì dropdown trống.
  // Giữ id nhân viên, không giữ tên hiển thị (tên có thể trùng).
  String _selectedColleague = '';
  List<ShiftStaffMember> _colleagues = [];

  // Đổi ca (Chọn ngày -> Chọn ca -> Chọn nhân viên trong ca)
  DateTime? _swapDate;
  String? _selectedTargetShift;
  ShiftStaffMember? _selectedSwapStaff;

  // Dữ liệu phân ca thực tế theo Ngày (DD/MM/YYYY) -> Ca -> Danh sách nhân viên.
  // Dựng từ /api/shifts, API rỗng thì map rỗng (hiện trống, không dùng mẫu cứng).
  Map<String, Map<String, List<ShiftStaffMember>>> _scheduleShiftStaffData = {};
  bool _loadingRefs = true;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  /// Chuẩn hóa mọi định dạng ngày backend (DD/MM/YYYY, ISO, dd-MM-yyyy) về khóa DD/MM/YYYY.
  String _dateKey(String raw) {
    final key = toVnDate(raw);
    return key.isNotEmpty ? key : raw.trim();
  }

  Future<void> _loadRefs() async {
    try {
      final results = await Future.wait([
        EmployeeRepository().getEmployees(),
        ShiftRepository().getShifts(),
        ShiftRepository().getTemplates(),
      ]);
      final emps = results[0] as List<Map<String, dynamic>>;
      final shifts = results[1] as List<ApiShiftModel>;
      final templates = results[2] as List<Map<String, dynamic>>;
      if (!mounted) return;
      final nameById = <String, String>{};
      final roleById = <String, String>{};
      final phoneById = <String, String>{};
      for (final e in emps) {
        final id = e['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        nameById[id] = e['name']?.toString() ?? id;
        roleById[id] = e['role']?.toString() ?? '';
        phoneById[id] = e['phone']?.toString() ?? '';
      }
      final templateNameById = <String, String>{
        for (final t in templates)
          if ((t['id']?.toString() ?? '').isNotEmpty)
            t['id'].toString(): t['name']?.toString() ?? '',
      };
      final colleagues = emps
          .where((e) => (e['id']?.toString() ?? '').isNotEmpty)
          .map((e) {
            final id = e['id'].toString();
            return ShiftStaffMember(
              id: id,
              name: nameById[id] ?? id,
              role: roleById[id] ?? '',
              phone: phoneById[id] ?? '',
            );
          })
          .toList();
      final grouped = <String, Map<String, List<ShiftStaffMember>>>{};
      for (final s in shifts) {
        if (s.workDate.trim().isEmpty) continue;
        final key = _dateKey(s.workDate);
        final templateName = templateNameById[s.templateId] ?? s.templateId;
        final label = '$templateName (${s.timeLabel})';
        final staff = ShiftStaffMember(
          id: s.employeeId ?? s.id,
          shiftId: s.id,
          name: (s.employeeId != null && nameById.containsKey(s.employeeId))
              ? nameById[s.employeeId]!
              : 'Chưa phân công',
          role: templateName,
          phone: (s.employeeId != null && phoneById.containsKey(s.employeeId))
              ? phoneById[s.employeeId]!
              : '',
        );
        grouped.putIfAbsent(key, () => {});
        grouped[key]!.putIfAbsent(label, () => []);
        if (staff.name != 'Chưa phân công' &&
            !grouped[key]![label]!.any((m) => m.id == staff.id)) {
          grouped[key]![label]!.add(staff);
        }
      }
      setState(() {
        _colleagues = colleagues;
        _scheduleShiftStaffData = grouped;
        _loadingRefs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRefs = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ Không tải được danh sách nhân sự/ca: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Xin nghỉ
  String _selectedLeaveReason = 'Bận việc gia đình đột xuất';
  final List<String> _leaveReasons = [
    'Bận việc gia đình đột xuất',
    'Khám bệnh / Lý do sức khỏe',
    'Trùng lịch thi cử / Học tập',
    'Việc cá nhân đột xuất',
    'Lý do khác',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _screenTitle {
    switch (widget.actionType) {
      case ShiftActionType.cover:
        return 'Nhờ làm thay';
      case ShiftActionType.swap:
        return 'Đổi ca làm việc';
      case ShiftActionType.leave:
        return 'Xin nghỉ ca làm việc';
    }
  }

  FaIconData get _actionIcon {
    switch (widget.actionType) {
      case ShiftActionType.cover:
        return FontAwesomeIcons.userPlus;
      case ShiftActionType.swap:
        return FontAwesomeIcons.arrowsLeftRight;
      case ShiftActionType.leave:
        return FontAwesomeIcons.calendarXmark;
    }
  }

  Color get _themeColor {
    switch (widget.actionType) {
      case ShiftActionType.cover:
        return Colors.orange.shade800;
      case ShiftActionType.swap:
        return AppColors.primary;
      case ShiftActionType.leave:
        return Colors.red.shade700;
    }
  }

  Future<void> _pickSwapDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _swapDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _swapDate = picked;
        _selectedTargetShift = null; // Reset ca để user chọn ca của ngày mới
        _selectedSwapStaff = null;   // Reset nhân viên
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.actionType == ShiftActionType.swap) {
      if (_swapDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ngày muốn đổi ca ở Bước 1')),
        );
        return;
      }
      if (_selectedTargetShift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ca làm việc ở Bước 2')),
        );
        return;
      }
      if (_selectedSwapStaff == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn nhân viên trong ca ở Bước 3')),
        );
        return;
      }
    }

    final me = UserScope.currentUser(context);
    if (me?.id == null || me!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không xác định được tài khoản, vui lòng đăng nhập lại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    final shiftLabel = '${widget.shift.shiftName} (${widget.shift.timeRange}) '
        'ngày ${toVnDate(widget.date)} tại ${widget.shift.branch}';
    String successMsg = '';
    String reqType = 'leave';
    String title = '';
    String content = '';
    String? targetShiftId;
    String? targetEmployeeId;
    Map<String, dynamic>? notification;

    Map<String, dynamic> baseNotification(String type) => {
          'requestType': type,
          'shiftName': widget.shift.shiftName,
          'shiftDate': toVnDate(widget.date),
          'shiftTime': widget.shift.timeRange,
          'shiftHours': widget.shift.hours?.toString() ?? '',
          'branch': widget.shift.branch,
          'shiftRole': widget.shift.role,
          'reason': reason,
          'senderName': me.name,
          'senderRole': me.role,
        };

    switch (widget.actionType) {
      case ShiftActionType.cover:
        final colleague = _colleagues.where((c) => c.id == _selectedColleague).toList();
        if (colleague.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn đồng nghiệp nhận làm thay')),
          );
          return;
        }
        final person = colleague.first;
        reqType = 'overtime';
        title = 'Nhờ làm thay: ${widget.shift.shiftName}';
        successMsg = '✅ Đã gửi lời nhờ làm thay tới ${person.displayName}!';
        targetEmployeeId = person.id;
        final coverNotif = baseNotification('cover');
        coverNotif.remove('reason');
        notification = coverNotif;
        content = 'Nhờ ${person.displayName} (mã ${person.id}'
            '${person.phone.isEmpty ? '' : ', SĐT ${person.phone}'}) làm thay ca: $shiftLabel.';
        break;
      case ShiftActionType.swap:
        final staff = _selectedSwapStaff!;
        if (staff.shiftId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Ca muốn đổi không có mã trên hệ thống, vui lòng chọn ca khác')),
          );
          return;
        }
        reqType = 'shift_swap';
        title = 'Đổi ca: ${widget.shift.shiftName}';
        successMsg = '✅ Đã gửi yêu cầu đổi ca tới ${staff.displayName}!';
        targetShiftId = staff.shiftId;
        targetEmployeeId = staff.id;
        final swapDateLabel = vnDate(_swapDate!);
        notification = {
          ...baseNotification('swap'),
          'swapShiftName': _selectedTargetShift ?? '',
          'swapShiftDate': swapDateLabel,
          'swapShiftBranch': widget.shift.branch,
          'swapShiftRole': staff.role,
        };
        content = 'Xin đổi ca với ${staff.displayName} (mã ${staff.id}).\n'
            'Ca của tôi: $shiftLabel.\n'
            'Ca muốn nhận: $_selectedTargetShift ngày $swapDateLabel.\n'
            'Lý do: $reason';
        break;
      case ShiftActionType.leave:
        reqType = 'leave';
        title = 'Xin nghỉ ca: ${widget.shift.shiftName}';
        successMsg = '✅ Đã gửi đơn xin nghỉ ca tới Quản lý chi nhánh!';
        content = 'Xin nghỉ ca: $shiftLabel.\n'
            'Lý do: $_selectedLeaveReason.\nChi tiết: $reason';
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await LeaveRepository().createRequest({
        'type': reqType,
        'title': title,
        'content': content,
        'employeeId': me.id,
        // Gửi id chi nhánh lên API, tên chỉ dùng hiển thị.
        if (widget.shift.branchId.isNotEmpty) 'branchId': widget.shift.branchId,
        if (widget.shift.id.isNotEmpty) 'sourceShiftId': widget.shift.id,
        if (targetShiftId != null) 'targetShiftId': targetShiftId,
        if (targetEmployeeId != null) 'targetEmployeeId': targetEmployeeId,
        if (notification != null) 'notification': notification,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(successMsg),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ Gửi yêu cầu thất bại: ${e is ApiException ? e.message : e}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final color = _themeColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Quay lại',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Thẻ thông tin ca hiện tại ─────────────────────────
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FaIcon(_actionIcon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            shift.shiftName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildShiftBadge(
                            FontAwesomeIcons.calendarDay,
                            '${widget.dayOfWeek}, ${toVnDate(widget.date)}',
                          ),
                        ),
                        Expanded(
                          child: _buildShiftBadge(
                            FontAwesomeIcons.clock,
                            shift.timeRange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildShiftBadge(
                            FontAwesomeIcons.store,
                            shift.branch,
                          ),
                        ),
                        if (shift.role.isNotEmpty)
                          Expanded(
                            child: _buildShiftBadge(
                              FontAwesomeIcons.idCard,
                              shift.role,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 2. Nội dung form theo từng loại ──────────────────────
              if (widget.actionType == ShiftActionType.cover) _buildCoverFields(),
              if (widget.actionType == ShiftActionType.swap) _buildSwapFields(),
              if (widget.actionType == ShiftActionType.leave) _buildLeaveFields(),

              const SizedBox(height: 30),

              // ── 3. Nút gửi ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 18),
                  label: const Text(
                    'Gửi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form fields: Nhờ làm thay ─────────────────────────────────────────
  Widget _buildCoverFields() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn đồng nghiệp nhận làm thay',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _colleagues.any((c) => c.id == _selectedColleague)
                ? _selectedColleague
                : null,
            hint: Text(
              _loadingRefs
                  ? 'Đang tải danh sách nhân sự...'
                  : _colleagues.isEmpty
                      ? 'Chưa có dữ liệu nhân sự'
                      : 'Chọn đồng nghiệp',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.orange, size: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _colleagues.map((c) {
              return DropdownMenuItem(
                value: c.id,
                child: Text(c.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedColleague = val);
            },
            validator: (val) {
              if (val == null || val.isEmpty) return 'Vui lòng chọn đồng nghiệp';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── Form fields: Đổi ca làm việc ──────────────────────────────────────
  Widget _buildSwapFields() {
    final String? dateKey = _swapDate != null ? vnDate(_swapDate!) : null;

    final String formattedDate = _swapDate != null ? vnDate(_swapDate!) : '';

    final Map<String, List<ShiftStaffMember>>? shiftsForDate =
        dateKey != null ? _scheduleShiftStaffData[dateKey] : null;

    final List<String> availableShifts = shiftsForDate?.keys.toList() ?? [];

    final List<ShiftStaffMember> availableStaffInShift =
        (_selectedTargetShift != null && shiftsForDate != null)
            ? (shiftsForDate[_selectedTargetShift] ?? [])
            : [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BƯỚC 1: CHỌN NGÀY ─────────────────────────────────────
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _swapDate != null ? AppColors.primary : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: _swapDate != null ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Chọn ngày muốn đổi ca',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickSwapDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _swapDate != null ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
                border: Border.all(
                  color: _swapDate != null ? AppColors.primary : Colors.grey.shade400,
                  width: _swapDate != null ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.calendarDays, color: _swapDate != null ? AppColors.primary : AppColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _swapDate != null ? 'Ngày đã chọn: $formattedDate' : 'Chạm để chọn ngày muốn đổi...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _swapDate != null ? FontWeight.bold : FontWeight.normal,
                        color: _swapDate != null ? AppColors.textPrimary : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (_swapDate != null)
                    const FaIcon(FontAwesomeIcons.circleCheck, color: AppColors.primary, size: 18)
                  else
                    const FaIcon(FontAwesomeIcons.caretDown, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── BƯỚC 2: CHỌN CA TRONG NGÀY ĐÓ (Hiện khi đã chọn ngày) ────────
          if (_swapDate != null) ...[
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedTargetShift != null ? AppColors.primary : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chọn ca làm việc trong ngày đó',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (availableShifts.isEmpty)
              _buildEmptyAlert('Không tìm thấy ca làm việc nào trong ngày $formattedDate.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey('shift_drop_${_swapDate != null ? vnDate(_swapDate!) : ''}_$_selectedTargetShift'),
                isExpanded: true,
                initialValue: _selectedTargetShift,
                hint: const Text('Chọn ca làm việc...'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: availableShifts.map((shiftName) {
                  final count = shiftsForDate?[shiftName]?.length ?? 0;
                  return DropdownMenuItem(
                    value: shiftName,
                    child: Text(
                      '$shiftName ($count nhân viên)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTargetShift = val;
                    _selectedSwapStaff = null; // Reset nhân viên khi đổi ca
                  });
                },
              ),
            const SizedBox(height: 20),
          ],

          // ── BƯỚC 3: CHỌN NGƯỜI ĐƯỢC XẾP TRONG CA (Hiện khi đã chọn ca) ───
          if (_selectedTargetShift != null) ...[
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedSwapStaff != null ? AppColors.primary : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chọn người được xếp trong ca đó',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (availableStaffInShift.isEmpty)
              _buildEmptyAlert('Ca này hiện chưa có nhân viên nào được phân công.')
            else
              DropdownButtonFormField<ShiftStaffMember>(
                key: ValueKey('staff_drop_${_selectedTargetShift}_${_selectedSwapStaff?.id}'),
                isExpanded: true,
                initialValue: _selectedSwapStaff,
                hint: const Text('Chọn đồng nghiệp trong ca...'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.group_outlined, color: AppColors.primary, size: 22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: availableStaffInShift.map((staff) {
                  return DropdownMenuItem(
                    value: staff,
                    child: Text(
                      '${staff.name} — ${staff.role}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSwapStaff = val);
                },
              ),
            const SizedBox(height: 20),
          ],

          // ── BƯỚC 4: LÝ DO ĐỔI CA (Hiện khi đã chọn người) ─────────
          if (_selectedSwapStaff != null) ...[
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '4',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lý do đổi ca',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập lý do gửi tới đồng nghiệp...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(14),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập lý do đổi ca';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildEmptyAlert(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleInfo, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form fields: Xin nghỉ ca ──────────────────────────────────────────
  Widget _buildLeaveFields() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lý do xin nghỉ ca',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedLeaveReason,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.event_busy_outlined, color: Colors.red, size: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: _leaveReasons.map((r) {
              return DropdownMenuItem(
                value: r,
                child: Text(r, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedLeaveReason = val);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Chi tiết lý do / Ghi chú gửi Quản lý',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập chi tiết lý do gửi tới Quản lý chi nhánh / Admin...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(14),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập chi tiết lý do xin nghỉ';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBadge(FaIconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FaIcon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
