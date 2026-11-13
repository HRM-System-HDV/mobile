import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../attendance/attendance_repository.dart';
import '../profile/employee_repository.dart';
import '../schedule/shift_repository.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class StaffMemberStatus {
  final String id;
  final String name;
  final String role;
  final String shift;
  final String checkInTime;
  final String? checkOutTime;
  final StaffAttendanceStatus status;
  final String avatar;

  const StaffMemberStatus({
    required this.id,
    required this.name,
    required this.role,
    required this.shift,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.avatar,
  });
}

enum StaffAttendanceStatus { present, late, absent, offShift }

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffMonitorScreen extends StatefulWidget {
  const StaffMonitorScreen({super.key});

  @override
  State<StaffMonitorScreen> createState() => _StaffMonitorScreenState();
}

class _StaffMonitorScreenState extends State<StaffMonitorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Chỉ dùng API thật (getEmployees + getAttendance) — khởi rỗng để hiện empty state
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  List<StaffMemberStatus> _staffList = [];
  // Lỗi tải dữ liệu: hiển thị rõ thay vì hiện "không có dữ liệu" như thật.
  String? _loadError;
  bool _loading = false;
  String? _loadedBranchId;
  // Token phiên tải để kết quả cũ không ghi đè kết quả mới khi đổi chi nhánh.
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _staffList = [];
    _fetchStaffAttendance();
  }

  Future<void> _fetchStaffAttendance() async {
    // Lấy chi nhánh đang chọn để lọc đúng phạm vi (BranchSelector có thật sự
    // ảnh hưởng dữ liệu, không chỉ là trang trí).
    final branch = BranchScope.selectedBranch(context);
    final branchId = branch?.id;
    // Token phiên tải: nếu người dùng đổi chi nhánh giữa chừng thì kết quả
    // cũ không được ghi đè lên kết quả mới.
    _requestToken += 1;
    final token = _requestToken;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final emps = await EmployeeRepository().getEmployees(branchId: branchId);
      final list = await _attendanceRepo.getAttendance(branchId: branchId);
      // Map ca thật từ API shifts (fallback 'Chưa rõ' khi không khớp)
      List<ApiShiftModel> apiShifts = [];
      final templateNames = <String, String>{};
      try {
        apiShifts = await ShiftRepository().getShifts(branchId: branchId);
        for (final t in await ShiftRepository().getTemplates()) {
          final id = t['id']?.toString() ?? '';
          final name = t['name']?.toString() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) templateNames[id] = name;
        }
      } catch (_) {
        apiShifts = [];
      }
      if (!mounted || token != _requestToken) return;
      final empById = <String, Map<String, dynamic>>{};
      for (final e in emps) {
        for (final k in ['id', 'email', 'employeeCode']) {
          final v = e[k]?.toString();
          if (v != null && v.isNotEmpty) empById[v] = e;
        }
      }
      final shiftNameById = <String, String>{};
      for (final s in apiShifts) {
        shiftNameById[s.id] = templateNames[s.templateId] ?? 'Chưa rõ';
      }
      final apiList = list.map((m) {
        StaffAttendanceStatus st = StaffAttendanceStatus.present;
        if (m.status == 'absent') st = StaffAttendanceStatus.absent;
        if (m.status == 'late') st = StaffAttendanceStatus.late;
        final emp = empById[m.employeeId];
        // Không khớp nhân viên thật -> 'Chưa rõ' (không dùng mock 'Nhân sự #...')
        final name = emp?['name']?.toString() ?? 'Chưa rõ';
        final role = emp?['role']?.toString() ?? (emp?['position']?.toString() ?? 'Chưa rõ');
        // Không khớp ca thật -> 'Chưa rõ' (không dùng 'Ca #...')
        final shift = shiftNameById[m.shiftId] ?? 'Chưa rõ';
        return StaffMemberStatus(
          id: m.id,
          name: name,
          role: role,
          shift: shift,
          checkInTime: m.checkIn ?? '--:--',
          checkOutTime: m.checkOut,
          status: st,
          avatar: name.isNotEmpty ? name[0].toUpperCase() : 'N',
        );
      }).toList();
      setState(() {
        _staffList = apiList;
        _loadedBranchId = branchId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _loading = false;
        // Lỗi mạng/403 không được hiển thị như "không có nhân sự".
        _loadError = e is ApiException
            ? e.message
            : 'Không tải được dữ liệu nhân sự. Kiểm tra kết nối hoặc thử lại.';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Đổi chi nhánh ở BranchSelector thì phải tải lại dữ liệu cho đúng phạm vi.
    final branchId = BranchScope.selectedBranch(context)?.id;
    if (branchId != _loadedBranchId && !_loading) {
      _fetchStaffAttendance();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<StaffMemberStatus> get _presentStaff =>
      _staffList.where((s) => s.status == StaffAttendanceStatus.present || s.status == StaffAttendanceStatus.late).toList();
  List<StaffMemberStatus> get _offShiftStaff =>
      _staffList.where((s) => s.status == StaffAttendanceStatus.offShift).toList();
  List<StaffMemberStatus> get _absentStaff =>
      _staffList.where((s) => s.status == StaffAttendanceStatus.absent).toList();

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserScope.isAdmin(context);
    // Tiêu đề phải nói đúng phạm vi dữ liệu đang hiển thị: có chi nhánh được
    // chọn thì là chi nhánh đó, không chọn thì là toàn công ty.
    final branch = BranchScope.selectedBranch(context);
    final String pageTitle = branch != null
        ? 'Nhân sự ${branch.name}'
        : (isAdmin ? 'Nhân sự toàn công ty' : 'Nhân sự toàn công ty');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: const BackButton(),
        actions: const [
          BranchSelector(includeAll: true),
        ],
      ),
      body: Column(
        children: [
          // Lỗi tải dữ liệu: không được hiện "không có nhân sự" như thật.
          if (_loadError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
                      _loadError!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A4B08)),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchStaffAttendance,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          // Tab bar
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
                Tab(text: 'Có mặt (${_presentStaff.length})'),
                Tab(text: 'Chưa vào (${ _offShiftStaff.length})'),
                Tab(text: 'Vắng (${_absentStaff.length})'),
              ],
            ),
          ),

          // Staff list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStaffList(_presentStaff),
                _buildStaffList(_offShiftStaff),
                _buildStaffList(_absentStaff),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(List<StaffMemberStatus> staffList) {
    if (staffList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchStaffAttendance,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          children: const [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.circleCheck, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('Không có nhân viên nào', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchStaffAttendance,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: staffList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final staff = staffList[index];
          return _buildStaffCard(staff);
        },
      ),
    );
  }

  Widget _buildStaffCard(StaffMemberStatus staff) {
    Color statusColor;
    String statusLabel;
    FaIconData statusIcon;

    switch (staff.status) {
      case StaffAttendanceStatus.present:
        statusColor = Colors.green;
        statusLabel = 'Đã vào ca';
        statusIcon = FontAwesomeIcons.circleCheck;
        break;
      case StaffAttendanceStatus.late:
        statusColor = Colors.orange;
        statusLabel = 'Đi muộn';
        statusIcon = FontAwesomeIcons.clock;
        break;
      case StaffAttendanceStatus.absent:
        statusColor = AppColors.error;
        statusLabel = 'Vắng mặt';
        statusIcon = FontAwesomeIcons.xmark;
        break;
      case StaffAttendanceStatus.offShift:
        statusColor = Colors.grey;
        statusLabel = 'Chưa vào ca';
        statusIcon = FontAwesomeIcons.clock;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              staff.avatar,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),

          // Name + role + shift
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(staff.role,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.clock, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        staff.shift,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status + check-in time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (staff.checkInTime != '--:--') ...[
                const SizedBox(height: 4),
                Text(
                  'Check-in: ${staff.checkInTime}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
