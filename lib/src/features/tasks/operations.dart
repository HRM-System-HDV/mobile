import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/models/user.dart';
import '../schedule/general.dart';
import '../salary/salary.dart';
import 'monitor.dart';
import '../approvals/approvals.dart';
import '../wifi_config/wifi.dart';
import '../leave_request/leave.dart';
import '../schedule/registration.dart';
import '../attendance/adjustment.dart';
import '../salary/advance.dart';
import '../news/news.dart';
import '../regulations/regulations.dart';
import '../home/help.dart';
import '../schedule/assignment.dart';
import 'tasks.dart';

class OperationsScreen extends StatelessWidget {
  final UserModel currentUser;
  final VoidCallback? onReturnHome;

  const OperationsScreen({
    super.key,
    required this.currentUser,
    this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = currentUser.isAdmin;
    final bool canManage = currentUser.canManage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Tác vụ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isAdmin) const BranchSelector(includeAll: true),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ── CỤM 1: QUẢN TRỊ (Chỉ hiển thị cho Quản trị viên & Quản lý) ──
          if (canManage) ...[
            _buildSubGroupLabel(
              'Quản trị',
              FontAwesomeIcons.userShield,
              AppColors.primary,
            ),
            _buildFeatureCard(
              title: isAdmin ? 'Nhân sự toàn công ty' : 'Nhân sự chi nhánh',
              icon: FontAwesomeIcons.users,
              iconColor: Colors.indigo,
              badgeText: isAdmin ? 'Toàn hệ thống' : 'Chi nhánh',
              badgeColor: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffMonitorScreen()),
                );
              },
            ),
            _buildFeatureCard(
              title: isAdmin ? 'Phê duyệt yêu cầu' : 'Duyệt yêu cầu chi nhánh',
              icon: FontAwesomeIcons.circleCheck,
              iconColor: Colors.orange.shade800,
              badgeText: 'Chờ duyệt',
              badgeColor: Colors.orange.shade800,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShiftRequestScreen()),
                );
              },
            ),
            _buildFeatureCard(
              title: 'Phân ca làm việc',
              icon: FontAwesomeIcons.calendarPlus,
              iconColor: AppColors.primary,
              badgeText: 'Xếp ca',
              badgeColor: AppColors.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ShiftAssignmentScreen(currentUser: currentUser)),
                );
              },
            ),
            _buildFeatureCard(
              title: 'Giao việc & Nhiệm vụ',
              icon: FontAwesomeIcons.listCheck,
              iconColor: AppColors.primary,
              badgeText: 'Giao việc',
              badgeColor: AppColors.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TaskListScreen(currentUser: currentUser)),
                );
              },
            ),
            _buildFeatureCard(
              title: isAdmin ? 'Cấu hình Wi-Fi' : 'Wi-Fi chi nhánh',
              icon: FontAwesomeIcons.wifi,
              iconColor: Colors.teal.shade700,
              badgeText: 'Wi-Fi Check',
              badgeColor: Colors.teal.shade700,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WifiConfigScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // ── CỤM 2: LỊCH LÀM VIỆC ──
          _buildSubGroupLabel(
            'Lịch làm việc',
            FontAwesomeIcons.calendarDays,
            const Color(0xFF1976D2),
          ),
          _buildFeatureCard(
            title: 'Lịch làm việc chung',
            icon: FontAwesomeIcons.calendarDays,
            iconColor: Colors.blue,
            badgeText: 'Chi nhánh',
            badgeColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GeneralScheduleScreen()),
              );
            },
          ),
          _buildFeatureCard(
            title: 'Đăng ký ca làm việc',
            icon: FontAwesomeIcons.calendarPlus,
            iconColor: const Color(0xFF1A73E8),
            badgeText: 'Tuần tới',
            badgeColor: const Color(0xFF1A73E8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleRegistrationScreen()),
              );
            },
          ),
          _buildFeatureCard(
            title: 'Đăng ký nghỉ phép',
            icon: FontAwesomeIcons.umbrellaBeach,
            iconColor: Colors.orange,
            badgeText: 'Phép năm',
            badgeColor: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
              );
            },
          ),
          _buildFeatureCard(
            title: 'Giao việc & Nhiệm vụ',
            icon: FontAwesomeIcons.listCheck,
            iconColor: const Color(0xFF2563EB),
            badgeText: 'Việc của tôi',
            badgeColor: const Color(0xFF2563EB),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TaskListScreen(currentUser: currentUser)),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 3: CHẤM CÔNG ──
          _buildSubGroupLabel(
            'Chấm công',
            FontAwesomeIcons.clock,
            const Color(0xFF00897B),
          ),
          _buildFeatureCard(
            title: 'Bổ sung / sửa chấm công',
            icon: FontAwesomeIcons.penToSquare,
            iconColor: Colors.teal,
            badgeText: 'Bù công',
            badgeColor: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceAdjustmentScreen()),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 4: LƯƠNG ──
          _buildSubGroupLabel(
            'Lương',
            FontAwesomeIcons.moneyBill,
            const Color(0xFF2E7D32),
          ),
          _buildFeatureCard(
            title: isAdmin
                ? 'Phiếu lương toàn công ty'
                : (canManage ? 'Bảng công & Lương chi nhánh' : 'Kỳ lương & Phiếu lương cá nhân'),
            icon: FontAwesomeIcons.receipt,
            iconColor: const Color(0xFF2E7D32),
            badgeText: 'Phiếu lương',
            badgeColor: const Color(0xFF2E7D32),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalaryScreen()),
              );
            },
          ),
          _buildFeatureCard(
            title: 'Tạm ứng lương',
            icon: FontAwesomeIcons.wallet,
            iconColor: const Color(0xFFFB8C00),
            badgeText: 'Tạm ứng',
            badgeColor: const Color(0xFFFB8C00),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalaryAdvanceScreen()),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 5: TRUYỀN THÔNG ──
          _buildSubGroupLabel(
            'Truyền thông',
            FontAwesomeIcons.bullhorn,
            const Color(0xFFE53935),
          ),
          _buildFeatureCard(
            title: 'Bảng tin & Thông báo',
            icon: FontAwesomeIcons.newspaper,
            iconColor: Colors.blueGrey,
            badgeText: 'Bản tin',
            badgeColor: Colors.blueGrey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NewsScreen(currentUser: currentUser)),
              );
            },
          ),
          _buildFeatureCard(
            title: 'Nội quy & Quy định',
            icon: FontAwesomeIcons.gavel,
            iconColor: const Color(0xFF6A1B9A),
            badgeText: 'Nội quy',
            badgeColor: const Color(0xFF6A1B9A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompanyRegulationsScreen(currentUser: currentUser)),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 6: HƯỚNG DẪN ──
          _buildSubGroupLabel(
            'Hướng dẫn',
            FontAwesomeIcons.circleQuestion,
            const Color(0xFF0288D1),
          ),
          _buildFeatureCard(
            title: 'Câu hỏi thường gặp & Trợ giúp',
            icon: FontAwesomeIcons.circleQuestion,
            iconColor: const Color(0xFF0288D1),
            badgeText: 'FAQ',
            badgeColor: const Color(0xFF0288D1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqHelpScreen()),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSubGroupLabel(String title, FaIconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 3.5, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Center(child: FaIcon(icon, size: 14, color: color)),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    String? subtitle,
    required FaIconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Center(
                  child: FaIcon(icon, color: iconColor, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
