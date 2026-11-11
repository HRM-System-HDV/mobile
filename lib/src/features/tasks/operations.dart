import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/models/user.dart';

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
                context.push('/tasks/monitor');
              },
            ),
            _buildFeatureCard(
              title: isAdmin ? 'Phê duyệt yêu cầu' : 'Duyệt yêu cầu chi nhánh',
              icon: FontAwesomeIcons.circleCheck,
              iconColor: Colors.orange.shade800,
              badgeText: 'Chờ duyệt',
              badgeColor: Colors.orange.shade800,
              onTap: () {
                context.push('/approvals');
              },
            ),
            _buildFeatureCard(
              title: 'Phân ca làm việc',
              icon: FontAwesomeIcons.calendarPlus,
              iconColor: AppColors.primary,
              badgeText: 'Xếp ca',
              badgeColor: AppColors.primary,
              onTap: () {
                context.push('/schedule/assignment', extra: currentUser);
              },
            ),
            _buildFeatureCard(
              title: 'Giao việc & Nhiệm vụ',
              icon: FontAwesomeIcons.listCheck,
              iconColor: AppColors.primary,
              badgeText: 'Giao việc',
              badgeColor: AppColors.primary,
              onTap: () {
                context.push('/tasks', extra: currentUser);
              },
            ),
            _buildFeatureCard(
              title: isAdmin ? 'Cấu hình Wi-Fi' : 'Wi-Fi chi nhánh',
              icon: FontAwesomeIcons.wifi,
              iconColor: Colors.teal.shade700,
              badgeText: 'Wi-Fi Check',
              badgeColor: Colors.teal.shade700,
              onTap: () {
                context.push('/wifi');
              },
            ),
            const SizedBox(height: 14),
          ],

          // ── CỤM 2: LỊCH LÀM VIỆC ──
          _buildSubGroupLabel(
            'Lịch làm việc',
            FontAwesomeIcons.calendarDays,
            AppColors.infoBlue,
          ),
          _buildFeatureCard(
            title: 'Lịch làm việc chung',
            icon: FontAwesomeIcons.calendarDays,
            iconColor: Colors.blue,
            badgeText: 'Chi nhánh',
            badgeColor: Colors.blue,
            onTap: () {
              context.push('/schedule/general');
            },
          ),
          _buildFeatureCard(
            title: 'Đăng ký ca làm việc',
            icon: FontAwesomeIcons.calendarPlus,
            iconColor: AppColors.infoBlue,
            badgeText: 'Tuần tới',
            badgeColor: AppColors.infoBlue,
            onTap: () {
              context.push('/schedule/registration');
            },
          ),
          _buildFeatureCard(
            title: 'Đăng ký nghỉ phép',
            icon: FontAwesomeIcons.umbrellaBeach,
            iconColor: Colors.orange,
            badgeText: 'Phép năm',
            badgeColor: Colors.orange,
            onTap: () {
              context.push('/leave');
            },
          ),
          _buildFeatureCard(
            title: 'Giao việc & Nhiệm vụ',
            icon: FontAwesomeIcons.listCheck,
            iconColor: AppColors.infoBlue,
            badgeText: 'Việc của tôi',
            badgeColor: AppColors.infoBlue,
            onTap: () {
              context.push('/tasks', extra: currentUser);
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 3: CHẤM CÔNG ──
          _buildSubGroupLabel(
            'Chấm công',
            FontAwesomeIcons.clock,
            AppColors.successDark,
          ),
          _buildFeatureCard(
            title: 'Bổ sung / sửa chấm công',
            icon: FontAwesomeIcons.penToSquare,
            iconColor: Colors.teal,
            badgeText: 'Bù công',
            badgeColor: Colors.teal,
            onTap: () {
              context.push('/attendance/adjustment');
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 4: LƯƠNG ──
          _buildSubGroupLabel(
            'Lương',
            FontAwesomeIcons.moneyBill,
            AppColors.successDark,
          ),
          _buildFeatureCard(
            title: isAdmin
                ? 'Phiếu lương toàn công ty'
                : (canManage ? 'Bảng công & Lương chi nhánh' : 'Kỳ lương & Phiếu lương cá nhân'),
            icon: FontAwesomeIcons.receipt,
            iconColor: AppColors.successDark,
            badgeText: 'Phiếu lương',
            badgeColor: AppColors.successDark,
            onTap: () {
              context.push('/salary');
            },
          ),
          _buildFeatureCard(
            title: 'Tạm ứng lương',
            icon: FontAwesomeIcons.wallet,
            iconColor: AppColors.warningDark,
            badgeText: 'Tạm ứng',
            badgeColor: AppColors.warningDark,
            onTap: () {
              context.push('/salary/advance');
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 5: TRUYỀN THÔNG ──
          _buildSubGroupLabel(
            'Truyền thông',
            FontAwesomeIcons.bullhorn,
            AppColors.error,
          ),
          _buildFeatureCard(
            title: 'Bảng tin & Thông báo',
            icon: FontAwesomeIcons.newspaper,
            iconColor: Colors.blueGrey,
            badgeText: 'Bản tin',
            badgeColor: Colors.blueGrey,
            onTap: () {
              context.push('/news', extra: currentUser);
            },
          ),
          _buildFeatureCard(
            title: 'Nội quy & Quy định',
            icon: FontAwesomeIcons.gavel,
            iconColor: AppColors.primary,
            badgeText: 'Nội quy',
            badgeColor: AppColors.primary,
            onTap: () {
              context.push('/regulations', extra: currentUser);
            },
          ),
          const SizedBox(height: 14),

          // ── CỤM 6: HƯỚNG DẪN ──
          _buildSubGroupLabel(
            'Hướng dẫn',
            FontAwesomeIcons.circleQuestion,
            AppColors.info,
          ),
          _buildFeatureCard(
            title: 'Câu hỏi thường gặp & Trợ giúp',
            icon: FontAwesomeIcons.circleQuestion,
            iconColor: AppColors.info,
            badgeText: 'FAQ',
            badgeColor: AppColors.info,
            onTap: () {
              context.push('/help');
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
