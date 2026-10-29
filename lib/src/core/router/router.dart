import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../../features/auth/splash.dart';
import '../../features/auth/login.dart';
import '../../features/home/main_nav.dart';

/// Single source of truth cho điều hướng toàn app.
///
/// Chuẩn go_router + MaterialApp.router:
/// - `/` → Splash kiểm tra phiên
/// - `/login` → Đăng nhập
/// - `/main` → Shell chính (IndexedStack 4 tabs), nhận [UserModel] qua `extra`.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) {
          final user = state.extra as UserModel? ??
              const UserModel(
                name: 'Trần Minh Tuấn',
                email: 'admin@company.com',
                role: 'admin',
                roleTitle: 'Quản trị viên',
              );
          return MainNavigationScreen(currentUser: user);
        },
      ),
    ],
  );
}
