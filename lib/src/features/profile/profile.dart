import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/models/user.dart';
import '../../core/utils/image_helper.dart';
import 'employee_repository.dart';
import '../auth/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProfileScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = UserScope.currentUser(context) ?? widget.currentUser;
    if (_loadedUserId != me.id && me.id.isNotEmpty) {
      _loadedUserId = me.id;
      _refreshProfile(me);
    }
  }

  Future<void> _refreshProfile(UserModel current) async {
    try {
      final data = await EmployeeRepository().getEmployee(current.id);
      if (data != null && mounted) {
        final updated = current.copyWith(
          avatarUrl: data['avatar']?.toString() ?? current.avatarUrl,
          phone: data['phone']?.toString() ?? current.phone,
          gender: data['gender']?.toString() ?? current.gender,
          birthDate: data['birthDate']?.toString() ?? current.birthDate,
          province: data['province']?.toString() ?? current.province,
          ward: data['ward']?.toString() ?? current.ward,
          street: data['street']?.toString() ?? current.street,
          cccd: data['cccd']?.toString() ?? current.cccd,
          issueDate: data['issueDate']?.toString() ?? current.issueDate,
          issuePlace: data['issuePlace']?.toString() ?? current.issuePlace,
          cccdFrontUrl: data['cccdFront']?.toString() ?? current.cccdFrontUrl,
          cccdBackUrl: data['cccdBack']?.toString() ?? current.cccdBackUrl,
          bankName: data['bankName']?.toString() ?? current.bankName,
          bankAccountNumber: data['bankAccountNumber']?.toString() ?? current.bankAccountNumber,
          bankAccountName: data['bankAccountName']?.toString() ?? current.bankAccountName,
        );
        UserScope.setUser(context, updated);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Đọc từ UserScope để tên/SĐT/ảnh cập nhật ngay sau khi lưu hồ sơ.
    final me = UserScope.currentUser(context) ?? widget.currentUser;
    final bool canManage = me.canManage;
    final String roleBadge = me.roleTitle;
    final phone = me.phone.isNotEmpty ? me.phone : '—';
    final avatarProvider = parseImageProvider(me.avatarUrl);

    // Chi nhánh của CHÍNH tài khoản (không phụ thuộc scope đang xem).
    // Luật 12/11: tài khoản bị ghim (manager/staff) chỉ hiện tên chi nhánh ở
    // đúng 1 chỗ duy nhất là tab "Cá nhân"; admin không bị ghim => hiện scope
    // đang xem ("Tất cả chi nhánh" hoặc chi nhánh đã chọn trên AppBar).
    // Nếu branchById không phân giải được (cache chưa nạp) thì hiện slug viết
    // hoa — tuyệt đối không bịa tên chi nhánh.
    final String pinnedBranch = (me.assignedBranchId?.trim() ?? '').isNotEmpty
        ? me.assignedBranchId!.trim()
        : (me.branchSlug?.trim() ?? '');
    String branchLabel = BranchScope.label(context);
    if (!me.isAdmin && pinnedBranch.isNotEmpty) {
      final lower = pinnedBranch.toLowerCase();
      final bool resolved = branches.any((b) =>
          b.id == pinnedBranch ||
          b.slug.toLowerCase() == lower ||
          b.code.toLowerCase() == lower);
      branchLabel = resolved ? branchById(pinnedBranch).name : pinnedBranch.toUpperCase();
    }

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
            onTap: () => context.push('/profile/info', extra: {
              'name': me.name,
              'email': me.email,
              'phone': phone,
              'isManager': canManage,
              'user': me,
            }),
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
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? FaIcon(canManage ? FontAwesomeIcons.userShield : FontAwesomeIcons.person, size: 28, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      // Dòng phụ: chức danh + chi nhánh (thay cho email, ẩn ở đây
                      // để thẻ chỉ còn 2 hàng đều nhau; email xem trong hồ sơ cá nhân).
                      Text('$roleBadge • $branchLabel',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
                  _buildProfileMenuItem(icon: FontAwesomeIcons.shieldHalved, title: 'Bảo mật', subtitle: 'Danh sách thiết bị đăng nhập, đổi mật khẩu', onTap: () => context.push('/profile/security')),
                  const Divider(height: 1),
                  _buildProfileMenuItem(icon: FontAwesomeIcons.bell, title: 'Cài đặt thông báo', subtitle: 'Tắt/bật các thông báo cần thiết', onTap: () => context.push('/profile/notifications')),
                  const Divider(height: 1),
                  InkWell(
                    onTap: () async {
                      await AuthRepository().logout();
                      if (!context.mounted) return;
                      UserScope.setUser(context, null);
                      context.go('/login');
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
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HRM System v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            Text('Hệ thống Quản lý Nhân sự nội bộ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
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