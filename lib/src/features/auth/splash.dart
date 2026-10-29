import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/models/user.dart';
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
    final results = await Future.wait([
      AuthRepository().me(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    final session = results[0];
    if (session is UserModel) {
      BranchScope.select(context, branchById(session.assignedBranchId ?? 'hn-1'));
      UserScope.setUser(context, session);
      context.go('/main', extra: session);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.badge_outlined, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'HRM Enterprise',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hệ thống Quản lý Nhân sự & Vận hành',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}