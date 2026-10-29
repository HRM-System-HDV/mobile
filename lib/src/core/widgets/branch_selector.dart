import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../models/branch.dart';
import '../../features/profile/employee_repository.dart';
import '../state/branch_scope.dart';
import '../state/user_scope.dart';

/// Nút chọn chi nhánh đặt trên AppBar của các tính năng quản trị.
///
/// Chỉ Quản trị viên (Admin) mới có quyền chuyển đổi chi nhánh.
/// Đối với nhân viên (Staff), hiển thị chi nhánh cố định và thông báo quyền hạn.
///
/// [includeAll] = true cho phép chọn "Tổng (Tất cả chi nhánh)" — chỉ áp dụng
/// cho các màn tổng hợp (giám sát nhân sự, phân công ca...).
class BranchSelector extends StatelessWidget {
  final bool includeAll;

  const BranchSelector({super.key, this.includeAll = true});

  @override
  Widget build(BuildContext context) {
    // Chỉ Quản trị viên (Admin) mới có quyền xem và chuyển đổi chi nhánh.
    // Đối với Quản lý (Manager) và Nhân viên (Staff), ẩn hoàn toàn nút này.
    final bool isAdmin = UserScope.isAdmin(context);
    if (!isAdmin) {
      return const SizedBox.shrink();
    }

    final branch = BranchScope.selectedBranch(context);
    final bool isAll = branch == null;
    final String branchName = branch?.name ?? 'Tổng';

    return IconButton(
      tooltip: 'Chọn chi nhánh (đang xem: $branchName)',
      onPressed: () => _showBranchPicker(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          FaIcon(
            isAll ? FontAwesomeIcons.store : FontAwesomeIcons.store,
            color: AppColors.textPrimary,
            size: 22,
          ),
          if (isAll)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showBranchPicker(BuildContext context) {
    if (!UserScope.isAdmin(context)) return;
    final current = BranchScope.selectedBranch(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        // Danh sách thật từ API (getBranches fallback kBranches khi lỗi)
        child: FutureBuilder<List<Branch>>(
          future: EmployeeRepository().getBranches(),
          initialData: kBranches,
          builder: (ctx, snap) {
            final branches = (snap.data == null || snap.data!.isEmpty) ? kBranches : snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Chọn chi nhánh',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                if (includeAll)
                  ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.buildingColumns,
                      color: current == null ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      'Tổng (Tất cả chi nhánh)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: current == null ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text('Gộp dữ liệu toàn hệ thống', style: TextStyle(fontSize: 11)),
                    trailing: current == null ? const FaIcon(FontAwesomeIcons.check, color: AppColors.primary) : null,
                    onTap: () {
                      BranchScope.select(context, null);
                      Navigator.pop(sheetContext);
                    },
                  ),
                for (final branch in branches)
                  ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.store,
                      color: current?.id == branch.id ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      branch.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: current?.id == branch.id ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(branch.address, style: const TextStyle(fontSize: 11)),
                    trailing: current?.id == branch.id ? const FaIcon(FontAwesomeIcons.check, color: AppColors.primary) : null,
                    onTap: () {
                      BranchScope.select(context, branch);
                      Navigator.pop(sheetContext);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}