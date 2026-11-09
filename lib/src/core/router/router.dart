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
/// - `/main` → Shell chính (IndexedStack 4 tabs), bắt buộc [UserModel] qua `extra`;
///   thiếu thì redirect về `/` để xác thực lại.
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
        // Thiếu user thật thì quay về splash xác thực lại, không tự dựng danh tính.
        redirect: (context, state) => state.extra is UserModel ? null : '/',
        builder: (context, state) => MainNavigationScreen(
          currentUser: state.extra as UserModel,
        ),
      ),
    ],
  );
}
