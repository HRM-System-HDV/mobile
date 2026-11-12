import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/permissions.dart';
import '../constants/colors.dart';
import '../state/user_scope.dart';

/// Màn báo không có quyền khi một tuyến bị chặn theo vai trò — tương đương
/// `NoAccessNotice` của web, nhưng dựng ở tầng route nên màn hình tính năng
/// không kịp hiện ra rồi mới báo lỗi.
class NoAccessScreen extends StatelessWidget {
  final String description;

  const NoAccessScreen({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Không có quyền truy cập'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 44, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chặn ngay trong GoRoute builder.
///
/// Vai trò lấy từ `UserScope` — cùng nguồn mà các màn hình đang dùng để xét
/// quyền, và luôn được set ở splash/login/main-nav trước khi vào nhóm tuyến
/// quản trị. `state.extra` không đáng tin vì nó do màn hình gọi push quyết định.
Widget guardRoute(BuildContext context, String route, Widget screen) {
  if (canAccessRoute(UserScope.currentUser(context), route)) return screen;
  return NoAccessScreen(description: permissionHintFor(route));
}
