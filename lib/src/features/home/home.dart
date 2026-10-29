import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/config/company.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/models/user.dart';
import '../schedule/schedule.dart';
import '../salary/salary.dart';
import '../leave_request/leave.dart';
import '../schedule/registration.dart';
import '../tasks/task_service.dart';
import '../tasks/task_repository.dart';
import '../tasks/tasks.dart';
import '../attendance/attendance_repository.dart';
import '../schedule/shift_repository.dart';
import '../wifi_config/wifi_config_repository.dart';

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({
    super.key,
    this.currentUser = const UserModel(
      name: 'Nguyễn Thu Hà',
      email: 'nhanvien@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ),
    this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ShiftDetail? _checkedInShift;
  DateTime? _checkedInTime;
  List<ApiShiftModel> _todayShifts = [];
  final WifiConfigRepository _wifiRepo = WifiConfigRepository();
  final TaskRepository _taskRepo = TaskRepository();
  List<WifiConfigModel> _wifiConfigs = [];
  List<TaskModel> _homeTasks = [];
  String? _loadedWifiBranchKey;
  String? _loadedTaskBranchKey;

  UserModel get currentUser => (mounted ? UserScope.currentUser(context) : null) ?? widget.currentUser;

  @override
  void initState() {
    super.initState();
    _todayShifts = [];
    _fetchTodayShifts();
    _loadHomeTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final branch = BranchScope.selectedBranch(context);
    final key = branch?.code ?? '__all__';
    if (_loadedWifiBranchKey != key) {
      _loadedWifiBranchKey = key;
      _fetchWifiConfigs(branchCode: branch?.code);
    }
    if (_loadedTaskBranchKey != key) {
      _loadedTaskBranchKey = key;
      _loadHomeTasks(branchSlug: branch?.slug);
    }
  }

  Future<void> _fetchTodayShifts() async {
    try {
      final shifts = await ShiftRepository().getShifts();
      // Gán vô điều kiện kể cả rỗng để hiện empty-state, không giữ mock.
      if (mounted) {
        setState(() => _todayShifts = shifts);
      }
    } catch (_) {
      // Chỉ dùng API thật: khi lỗi/offline giữ danh sách rỗng để hiện empty-state.
      if (mounted) {
        setState(() => _todayShifts = []);
      }
    }
  }

  Future<void> _fetchWifiConfigs({String? branchCode}) async {
    try {
      final configs = await _wifiRepo.getWifiConfigs(branch: branchCode ?? '');
      // Gán vô điều kiện kể cả rỗng (fallback hiển thị '—'), không dùng mock.
      if (mounted) {
        setState(() => _wifiConfigs = configs);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _wifiConfigs = []);
      }
    }
  }

  Future<void> _loadHomeTasks({String? branchSlug}) async {
    try {
      final tasks = await _taskRepo.getTasks(branchSlug: branchSlug);
      // Gán vô điều kiện kể cả rỗng để hiện empty-state, không dùng mock.
      if (mounted) {
        setState(() => _homeTasks = tasks);
      }
    } catch (_) {
      // Lỗi thì list rỗng + empty-state, không dùng mock.
      if (mounted) {
        setState(() => _homeTasks = []);
      }
    }
  }

  /// SSID Wi-Fi chấm công lấy từ API wifi-configs theo chi nhánh, fallback '—'.
  String _wifiSsidOrDash() {
    if (_wifiConfigs.isNotEmpty && _wifiConfigs.first.ssid.isNotEmpty) {
      return _wifiConfigs.first.ssid;
    }
    return '—';
  }

  /// Nhãn BSSID từ config Wi-Fi thực tế, fallback '—' nếu không có.
  String _wifiBssidLabel() {
    if (_wifiConfigs.isNotEmpty && _wifiConfigs.first.bssid.isNotEmpty) {
      return 'BSSID: ${_wifiConfigs.first.bssid} (Hợp lệ)';
    }
    return 'BSSID: —';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            onPressed: () {
              if (widget.onNavigateToTab != null) widget.onNavigateToTab!(2); // Switch to Notifications
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildCheckInOutButton(context),
              const SizedBox(height: 24),

                  // Lưới tác vụ nhanh 2x2 chuẩn HRM (Lịch làm việc, Đăng ký nghỉ, Kỳ lương, Bảng tin)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          title: 'Lịch làm việc',
                          subtitle: 'Xem ca & phân công',
                          icon: Icons.calendar_month_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionCard(
                          title: 'Đăng ký nghỉ',
                          subtitle: 'Nghỉ ngày/ Nghỉ ca',
                          icon: Icons.beach_access_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          title: 'Kỳ lương',
                          subtitle: 'Tạm tính thu nhập',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionCard(
                          title: 'Đăng ký ca làm',
                          subtitle: 'Chọn ca tuần tới',
                          icon: Icons.event_available_rounded,
                          color: const Color(0xFF0EA5E9),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleRegistrationScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTodoSection(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Chào buổi sáng 👋';
    if (hour >= 12 && hour < 18) return 'Chào buổi chiều 👋';
    return 'Chào buổi tối 👋';
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              currentUser.canManage ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 15, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        CompanyConfig.shortName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInOutButton(BuildContext context) {
    final bool isCheckedIn = _checkedInShift != null;

    // Khi đã chấm công vào: chuyển nút sang màu vàng/amber nổi bật; khi chưa: màu đỏ
    final List<Color> gradientColors = isCheckedIn
        ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
        : const [AppColors.primary, AppColors.primaryDark];

    final Color shadowColor = isCheckedIn
        ? const Color(0xFFD97706).withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.4);

    final String titleText = isCheckedIn ? 'Chấm công ra ca' : 'Chấm công vào ca';

    final String subtitleText = isCheckedIn
        ? 'Đang làm: ${_checkedInShift!.shiftName} (${_checkedInShift!.timeRange})'
        : 'Chạm để xác thực Wi-Fi chi nhánh';

    final IconData mainIcon = isCheckedIn ? Icons.timer_outlined : Icons.touch_app_rounded;

    return Container(
      width: double.infinity,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isCheckedIn) {
              _showCheckOutSheet(context);
            } else {
              _showCheckInSheet(context);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(mainIcon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getShiftStatusColor(String status) => ScheduleService.getStatusColor(status);

  String _getShiftStatusLabel(String status) => ScheduleService.getStatusLabel(status);

  void _showCheckInSheet(BuildContext context) {
    final branch = BranchScope.selectedBranch(context);
    // SSID lấy từ API wifi-configs theo chi nhánh, fallback '—' nếu không có.
    final String wifiSsid = _wifiSsidOrDash();
    final String wifiBssidLabel = _wifiBssidLabel();

    // Lấy danh sách ca làm việc được phân công cho nhân viên trong hôm nay
    final assignedShifts = ScheduleService.getTodayAssignedShiftsWithApi(
      apiShifts: _todayShifts,
      user: currentUser,
      branchName: branch?.name,
      activeCheckedInShift: _checkedInShift,
    );

    ShiftDetail? selectedShift = assignedShifts.isNotEmpty ? assignedShifts.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool hasAssignedShifts = assignedShifts.isNotEmpty;
          final double sheetHeight = MediaQuery.of(context).size.height * 0.52;

          return Container(
            height: sheetHeight,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chấm công vào ca làm việc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Chọn ca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),

                        if (hasAssignedShifts)
                          DropdownButtonFormField<ShiftDetail>(
                            isExpanded: true,
                            initialValue: selectedShift,
                            items: assignedShifts.map((shift) {
                              return DropdownMenuItem<ShiftDetail>(
                                value: shift,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${shift.shiftName} (${shift.timeRange})',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: _getShiftStatusColor(shift.status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getShiftStatusLabel(shift.status),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: _getShiftStatusColor(shift.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() {
                                  selectedShift = value;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.event_busy_rounded, color: Color(0xFFD97706), size: 24),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Không có ca làm việc hôm nay',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Bạn chưa được xếp vào ca nào trong ngày hôm nay. Vui lòng liên hệ Quản lý nếu cần bổ sung ca.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📡 Wi-Fi kết nối: $wifiSsid',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                wifiBssidLabel,
                                style: const TextStyle(color: AppColors.success, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: hasAssignedShifts && selectedShift != null
                      ? () async {
                          final targetShift = selectedShift!;
                          final now = DateTime.now();
                          try {
                            await AttendanceRepository().checkIn(
                              employeeId: currentUser.id,
                              shiftId: targetShift.id.isNotEmpty ? targetShift.id : targetShift.shiftName,
                              wifiSsid: wifiSsid,
                              checkinTime: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            setState(() {
                              _checkedInShift = targetShift;
                              _checkedInTime = now;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('✅ Chấm công vào ${targetShift.shiftName} (${targetShift.timeRange}) thành công!'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFFDC2626),
                                content: Text('❌ Chấm công thất bại: $e'),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    hasAssignedShifts ? 'Xác nhận Chấm công' : 'Chưa được xếp ca làm việc',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatCurrency(num value) {
    final str = value.toInt().toString();
    return str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  void _showCheckOutSheet(BuildContext context) {
    if (_checkedInShift == null) return;
    final shift = _checkedInShift!;
    // SSID lấy từ API wifi-configs theo chi nhánh, fallback '—' nếu không có.
    final String wifiSsid = _wifiSsidOrDash();
    final String wifiBssidLabel = _wifiBssidLabel();

    final String checkInTimeStr = _checkedInTime != null
        ? '${_checkedInTime!.hour.toString().padLeft(2, '0')}:${_checkedInTime!.minute.toString().padLeft(2, '0')}'
        : '—';

    final user = widget.currentUser;
    final bool isHourly = user.isHourlySalary;
    final double hoursWorked = shift.hours > 0 ? shift.hours : 5.0;
    final int earnedMoney = (hoursWorked * user.hourlySalary).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final double sheetHeight = MediaQuery.of(context).size.height * 0.65;

        return Container(
          height: sheetHeight,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chấm công ra ca làm việc',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Ca làm việc đang thực hiện', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),

                      // Card ca làm việc đã chấm công vào để chấm công ra ca
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${shift.shiftName} (${shift.timeRange})',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Đang trong ca',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Vai trò: ${shift.role}\n• Chi nhánh: ${shift.branch}\n• Đã chấm công vào lúc: $checkInTimeStr',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📡 Wi-Fi kết nối: $wifiSsid',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              wifiBssidLabel,
                              style: const TextStyle(color: AppColors.success, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isHourly ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHourly ? Colors.green.shade300 : Colors.blueGrey.shade200,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FaIcon(
                                  isHourly ? FontAwesomeIcons.moneyBillWave : FontAwesomeIcons.fileInvoiceDollar,
                                  size: 16,
                                  color: isHourly ? AppColors.success : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isHourly ? 'Tính công ra ca (Lương theo giờ)' : 'Cơ chế tính lương (Cố định tháng)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: isHourly ? Colors.green.shade900 : Colors.blueGrey.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isHourly) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tiền công ca (${hoursWorked}h × ${_formatCurrency(user.hourlySalary)} ₫/h):',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    '+${_formatCurrency(earnedMoney)} ₫',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '💡 Được tự động cộng dồn vào bảng công ngay khi hoàn thành ra ca.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ] else ...[
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Khấu trừ phạt ca:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text('0 ₫ (Không bị phạt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '💡 Nhân viên hưởng lương cơ bản tháng. Ca làm việc không cộng/trừ giờ, chỉ hiển thị số tiền trừ khi có vi phạm phạt.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final shiftOut = _checkedInShift;
                  final now = DateTime.now();
                  try {
                    await AttendanceRepository().checkOut(
                      employeeId: currentUser.id,
                      shiftId: shiftOut != null && shiftOut.id.isNotEmpty ? shiftOut.id : shiftOut?.shiftName,
                      checkoutTime: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {
                      _checkedInShift = null;
                      _checkedInTime = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text(isHourly
                            ? '✅ Chấm công ra ca ${shiftOut?.shiftName ?? ''} thành công! Đã cộng công: +${_formatCurrency(earnedMoney)} ₫ (${hoursWorked}h)'
                            : '✅ Chấm công ra ca ${shiftOut?.shiftName ?? ''} thành công! (Lương tháng cố định)'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFDC2626),
                        content: Text('❌ Chấm công ra ca thất bại: $e'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Xác nhận Ra ca',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodoSection(BuildContext context) {
    // Chỉ dùng TaskRepository API. Khi lỗi thì list rỗng + empty-state, không dùng mock.
    final tasks = _homeTasks;
    final activeTasks = tasks.where((t) => t.computedStatus != TaskStatus.completed).toList();
    final displayTasks = activeTasks.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Công việc cần làm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (activeTasks.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeTasks.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TaskListScreen(currentUser: currentUser)),
                    );
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Xem tất cả', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (displayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(Icons.checklist_rounded, size: 30, color: AppColors.primary.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Không có công việc tồn đọng', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Bạn đã hoàn thành tất cả nhiệm vụ được giao!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: displayTasks.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, index) {
                final task = displayTasks[index];
                final isOverdue = task.computedStatus == TaskStatus.overdue;

                return InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TaskListScreen(currentUser: currentUser)),
                    );
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (task.requirePhoto) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📸 Nhiệm vụ này bắt buộc chụp ảnh kết quả. Vui lòng chụp ảnh minh chứng!'),
                                  backgroundColor: Color(0xFFDC2626),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TaskListScreen(currentUser: currentUser)),
                              );
                              setState(() {});
                            } else {
                              try {
                                await _taskRepo.updateTaskStatus(task.id, 'completed');
                                if (!context.mounted) return;
                                setState(() {
                                  task.status = TaskStatus.completed;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Đã hoàn thành: ${task.title}'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Cập nhật công việc thất bại: $e'),
                                    backgroundColor: const Color(0xFFDC2626),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: task.requirePhoto ? const Color(0xFFDC2626) : Colors.grey.shade400,
                                width: 1.6,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: task.requirePhoto
                                ? const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFFDC2626))
                                : null,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: task.sourceColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(task.sourceIcon, size: 12, color: task.sourceColor),
                                        const SizedBox(width: 3),
                                        Text(task.shortSourceLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: task.sourceColor)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isOverdue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Quá giờ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.title,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${task.assignedByName} • Hạn: ${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11.5, color: isOverdue ? const Color(0xFFDC2626) : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
