import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/models/user.dart';
import 'info.dart';
import '../auth/auth_repository.dart';
import '../auth/login.dart';
import 'notif_settings.dart';
import 'security.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProfileScreen({
    super.key,
    this.currentUser = const UserModel(
      name: 'Nguyễn Thu Hà',
      email: 'nhanvien@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ),
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _phoneController = TextEditingController(
      text: widget.currentUser.phone.isNotEmpty ? widget.currentUser.phone : '—',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.currentUser.canManage;
    final String roleBadge = widget.currentUser.roleTitle;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header Profile
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonalInfoScreen(
                  name: _nameController.text,
                  email: widget.currentUser.email,
                  phone: _phoneController.text,
                  isManager: canManage,
                  user: widget.currentUser,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: FaIcon(canManage ? FontAwesomeIcons.userShield : FontAwesomeIcons.person, size: 28, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_nameController.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('$roleBadge • ${widget.currentUser.email}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: canManage ? AppColors.primary.withValues(alpha: 0.10) : Colors.blue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(BranchScope.label(context), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: canManage ? AppColors.primary : Colors.blue.shade700)),
                      ),
                    ]),
                  ),
                  const FaIcon(FontAwesomeIcons.chevronRight, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 8),

          // Action list — học từ ảnh HRM nhưng diễn giải lại bằng style F&B (icon + title + subtitle + chevron)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildProfileMenuItem(icon: FontAwesomeIcons.shieldHalved, title: 'Bảo mật', subtitle: 'Danh sách thiết bị đăng nhập, đổi mật khẩu', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                  const Divider(height: 1),
                  _buildProfileMenuItem(icon: FontAwesomeIcons.bell, title: 'Cài đặt thông báo', subtitle: 'Tắt/bật các thông báo cần thiết', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
                  const Divider(height: 1),
                  InkWell(
                    onTap: () async {
                      await AuthRepository().logout();
                      if (!context.mounted) return;
                      UserScope.setUser(context, null);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          FaIcon(FontAwesomeIcons.rightFromBracket, color: Colors.red),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Đăng xuất',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          FaIcon(FontAwesomeIcons.chevronRight, size: 20, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HRM System v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Text('Hệ thống Quản lý Nhân sự nội bộ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Row(children: [
                  const FaIcon(FontAwesomeIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Container(width: 22, height: 14, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2)), child: const Center(child: Text('★', style: TextStyle(color: Colors.yellow, fontSize: 10)))),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({required FaIconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            FaIcon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const FaIcon(FontAwesomeIcons.chevronRight, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // _buildEditableRow/_buildInfoRow đã chuyển vào PersonalInfoScreen
}