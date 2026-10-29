import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import '../../core/models/user.dart';
import 'home.dart';
import '../tasks/operations.dart';
import '../notifications/notifications.dart';
import '../profile/profile.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final UserModel currentUser;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.currentUser = const UserModel(
      name: 'Nguyễn Thu Hà',
      email: 'nhanvien@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ),
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    UserScope.setUser(context, widget.currentUser);
  }

  void _setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        currentUser: widget.currentUser,
        onNavigateToTab: _setTabIndex,
      ),
      OperationsScreen(
        currentUser: widget.currentUser,
        onReturnHome: () => _setTabIndex(0),
      ),
      const NotificationsScreen(),
      ProfileScreen(
        currentUser: widget.currentUser,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: NotificationState.unreadCount,
          builder: (context, unreadCount, _) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              onTap: _setTabIndex,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Trang chủ',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view_rounded),
                  label: 'Tác vụ',
                ),
                BottomNavigationBarItem(
                  icon: Badge.count(
                    count: unreadCount,
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: const Color(0xFFDC2626),
                    textColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  activeIcon: Badge.count(
                    count: unreadCount,
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: const Color(0xFFDC2626),
                    textColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: 'Thông báo',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Tài khoản',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
