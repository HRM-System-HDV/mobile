import 'package:flutter/material.dart';
import 'core/models/branch.dart';
import 'core/router/router.dart';
import 'core/state/branch_scope.dart';
import 'core/state/user_scope.dart';
import 'core/theme/theme.dart';
import 'core/models/user.dart';

class HRMApp extends StatefulWidget {
  const HRMApp({super.key});

  @override
  State<HRMApp> createState() => _HRMAppState();
}

class _HRMAppState extends State<HRMApp> {
  final ValueNotifier<Branch?> _selectedBranch = ValueNotifier<Branch?>(null);
  final ValueNotifier<UserModel?> _currentUser = ValueNotifier<UserModel?>(null);

  @override
  void dispose() {
    _selectedBranch.dispose();
    _currentUser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HRM Enterprise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) => UserScope(
        notifier: _currentUser,
        child: BranchScope(
          notifier: _selectedBranch,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
