import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/permissions.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';
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

  /// Ảnh đại diện và số điện thoại chỉ có trong hồ sơ nhân sự
  /// (GET /api/employees/:employeeId), không nằm trong token user.
  String? _avatarUrl;
  String? _phone;

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
    final employeeId = current.employeeId;
    if (employeeId == null || employeeId.isEmpty) return;
    try {
      final data = await EmployeeRepository().getEmployee(employeeId);
      if (data == null || !mounted) return;
      setState(() {
        _avatarUrl = data['avatar']?.toString();
        _phone = data['phone']?.toString();
      });
      UserScope.setUser(
        context,
        current.copyWith(
          gender: data['gender']?.toString(),
          birthDate: data['birthDate']?.toString(),
          province: data['province']?.toString(),
          ward: data['ward']?.toString(),
          street: data['street']?.toString(),
          cccd: data['cccd']?.toString(),
          issueDate: data['issueDate']?.toString(),
          issuePlace: data['issuePlace']?.toString(),
          salaryType: data['salaryType']?.toString(),
          cccdBackUrl: data['cccdBack']?.toString(),
          bankName: data['bankName']?.toString(),
          bankAccountNumber: data['bankAccountNumber']?.toString(),
          bankAccountName: data['bankAccountName']?.toString(),
        ),
      );
    } catch (e) {
      // Lỗi tải hồ sơ: giữ dữ liệu cache trên màn, không báo là "không có hồ sơ".
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e is ApiException ? e.message : 'Không tải được hồ sơ nhân sự'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Đọc từ UserScope để tên/SĐT/ảnh cập nhật ngay sau khi lưu hồ sơ.
    final me = UserScope.currentUser(context) ?? widget.currentUser;
    final bool canManage = me.canManage;
    final String roleBadge = kRoleLabels[roleOf(me)] ?? 'Nhân viên';
    final avatarProvider = parseImageProvider(_avatarUrl);

    // Chi nhánh của CHÍNH tài khoản (không phụ thuộc scope đang xem).
    // Luật 12/11: tài khoản bị ghim (manager/staff) chỉ hiện tên chi nhánh ở
    // đúng 1 chỗ duy nhất là tab "Cá nhân"; admin không bị ghim => hiện scope
    // đang xem ("Tất cả chi nhánh" hoặc chi nhánh đã chọn trên AppBar).
    // pinnedBranch là UUID chi nhánh (branchId); nếu branchById không phân giải
    // được (cache chưa nạp) thì hiện mã viết hoa — tuyệt đối không bịa tên.
    final String pinnedBranch = me.assignedBranchId?.trim() ?? '';
    String branchLabel = BranchScope.label(context);
    if (!me.isAdmin && pinnedBranch.isNotEmpty) {
      final lower = pinnedBranch.toLowerCase();
      final bool resolved = branches.any((b) =>
          b.id == pinnedBranch || b.code.toLowerCase() == lower);
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
              'phone': _phone ?? '',
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