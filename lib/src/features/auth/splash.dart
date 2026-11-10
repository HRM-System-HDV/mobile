import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import 'auth_repository.dart';

/// Màn hình khởi động (splash) — kiểm tra phiên thật qua `GET /api/auth/me`.
/// Còn phiên -> vào thẳng `/main`, hết phiên -> sang `/login`.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    await ApiClient.restoreSession();
    final results = await Future.wait([
      AuthRepository().me(),
      Future.delayed(const Duration(milliseconds: 1000)),
    ]);
    if (!mounted) return;
    final session = results[0];
    if (session is UserModel) {
      if (session.assignedBranchId != null && session.assignedBranchId!.isNotEmpty) {
        BranchScope.select(context, branchById(session.assignedBranchId!));
      } else {
        BranchScope.select(context, null);
      }
      UserScope.setUser(context, session);
      context.go('/main', extra: session);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HRM Enterprise',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Hệ thống Quản lý Nhân sự & Vận hành',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 36),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}