import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../state/user_scope.dart';
import '../widgets/no_access_screen.dart';

import '../../features/auth/splash.dart';
import '../../features/auth/login.dart';
import '../../features/home/main_nav.dart';
import '../../features/home/help.dart';

import '../../features/schedule/schedule.dart';
import '../../features/schedule/general.dart';
import '../../features/schedule/registration.dart';
import '../../features/schedule/assignment.dart';
import '../../features/schedule/shift_detail.dart';
import '../../features/schedule/shift_form.dart';
import '../../features/schedule/staff_detail.dart';

import '../../features/leave_request/leave.dart';
import '../../features/attendance/adjustment.dart';

import '../../features/salary/salary.dart';
import '../../features/salary/advance.dart';

import '../../features/tasks/tasks.dart';
import '../../features/tasks/monitor.dart';
import '../../features/tasks/operations.dart';

import '../../features/approvals/approvals.dart' hide ShiftRequestStatus;
import '../../features/wifi_config/wifi.dart';

import '../../features/news/news.dart';
import '../../features/regulations/regulations.dart';

import '../../features/profile/info.dart';
import '../../features/profile/security.dart';
import '../../features/profile/devices.dart';
import '../../features/profile/password.dart';
import '../../features/profile/notif_settings.dart';

import '../../features/notifications/request_detail.dart';

UserModel _resolveUser(BuildContext context, GoRouterState state) {
  if (state.extra is UserModel) return state.extra as UserModel;
  final current = UserScope.currentUser(context);
  if (current != null) return current;
  return const UserModel(
    name: '',
    email: '',
    role: 'staff',
  );
}

/// Single source of truth cho điều hướng toàn app.
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
        redirect: (context, state) => state.extra is UserModel ? null : '/',
        builder: (context, state) => MainNavigationScreen(
          currentUser: state.extra as UserModel,
        ),
      ),
      GoRoute(
        path: '/schedule',
        name: 'schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/schedule/general',
        name: 'schedule_general',
        builder: (context, state) => const GeneralScheduleScreen(),
      ),
      GoRoute(
        path: '/schedule/registration',
        name: 'schedule_registration',
        builder: (context, state) => const ScheduleRegistrationScreen(),
      ),
      GoRoute(
        path: '/schedule/assignment',
        name: 'schedule_assignment',
        builder: (context, state) => guardRoute(
          context,
          '/schedule/assignment',
          ShiftAssignmentScreen(currentUser: _resolveUser(context, state)),
        ),
      ),
      GoRoute(
        path: '/schedule/detail',
        name: 'schedule_detail',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            return ShiftDetailScreen(
              shift: m['shift'] as ShiftDetail,
              date: m['date']?.toString() ?? '',
              dayOfWeek: m['dayOfWeek']?.toString() ?? '',
            );
          }
          if (state.extra is ShiftDetail) {
            return ShiftDetailScreen(
              shift: state.extra as ShiftDetail,
              date: '',
              dayOfWeek: '',
            );
          }
          return const ScheduleScreen();
        },
      ),
      GoRoute(
        path: '/schedule/form',
        name: 'schedule_form',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            return ShiftActionFormScreen(
              shift: m['shift'] as ShiftDetail,
              date: m['date']?.toString() ?? '',
              dayOfWeek: m['dayOfWeek']?.toString() ?? '',
              actionType: m['actionType'] as ShiftActionType? ?? ShiftActionType.leave,
            );
          }
          return const ScheduleScreen();
        },
      ),
      GoRoute(
        path: '/schedule/staff-detail',
        name: 'schedule_staff_detail',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            return StaffGeneralShiftDetailScreen(
              staff: m['staff'] as StaffInShift,
              shift: m['shift'] as GeneralShiftModel,
              day: m['day'] as GeneralDayModel,
              gracePeriodMinutes: m['gracePeriodMinutes'] as int? ?? 5,
              checkoutWindowMinutes: m['checkoutWindowMinutes'] as int? ?? 60,
            );
          }
          return const GeneralScheduleScreen();
        },
      ),
      GoRoute(
        path: '/leave',
        name: 'leave',
        builder: (context, state) => const LeaveRequestScreen(),
      ),
      GoRoute(
        path: '/attendance/adjustment',
        name: 'attendance_adjustment',
        builder: (context, state) => const AttendanceAdjustmentScreen(),
      ),
      GoRoute(
        path: '/salary',
        name: 'salary',
        builder: (context, state) => const SalaryScreen(),
      ),
      GoRoute(
        path: '/salary/advance',
        name: 'salary_advance',
        builder: (context, state) => const SalaryAdvanceScreen(),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) {
          final user = _resolveUser(context, state);
          final filter = state.extra is Map<String, dynamic>
              ? (state.extra as Map<String, dynamic>)['initialFilter'] as String?
              : null;
          return TaskListScreen(currentUser: user, initialFilter: filter);
        },
      ),
      GoRoute(
        path: '/tasks/operations',
        name: 'tasks_operations',
        builder: (context, state) => OperationsScreen(
          currentUser: _resolveUser(context, state),
        ),
      ),
      GoRoute(
        path: '/tasks/monitor',
        name: 'tasks_monitor',
        builder: (context, state) =>
            guardRoute(context, '/tasks/monitor', const StaffMonitorScreen()),
      ),
      GoRoute(
        path: '/approvals',
        name: 'approvals',
        builder: (context, state) =>
            guardRoute(context, '/approvals', const ShiftRequestScreen()),
      ),
      GoRoute(
        path: '/wifi',
        name: 'wifi',
        builder: (context, state) =>
            guardRoute(context, '/wifi', const WifiConfigScreen()),
      ),
      GoRoute(
        path: '/news',
        name: 'news',
        builder: (context, state) => NewsScreen(
          currentUser: _resolveUser(context, state),
        ),
      ),
      GoRoute(
        path: '/regulations',
        name: 'regulations',
        builder: (context, state) => CompanyRegulationsScreen(
          currentUser: _resolveUser(context, state),
        ),
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const FaqHelpScreen(),
      ),
      GoRoute(
        path: '/profile/info',
        name: 'profile_info',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            return PersonalInfoScreen(
              name: m['name']?.toString() ?? '',
              email: m['email']?.toString() ?? '',
              phone: m['phone']?.toString() ?? '',
              isManager: m['isManager'] == true,
              user: m['user'] as UserModel?,
            );
          }
          final me = _resolveUser(context, state);
          return PersonalInfoScreen(
            name: me.name,
            email: me.email,
            // SĐT không có trong token user — màn hồ sơ tự đọc từ hồ sơ nhân sự.
            phone: '',
            isManager: me.canManage,
            user: me,
          );
        },
      ),
      GoRoute(
        path: '/profile/security',
        name: 'profile_security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/profile/devices',
        name: 'profile_devices',
        builder: (context, state) => const LoggedInDevicesScreen(),
      ),
      GoRoute(
        path: '/profile/password',
        name: 'profile_password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        name: 'profile_notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/notifications/detail',
        name: 'notifications_detail',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final m = state.extra as Map<String, dynamic>;
            return ShiftRequestDetailScreen(
              requestId: m['requestId']?.toString() ?? '',
              title: m['title']?.toString() ?? '',
              senderName: m['senderName']?.toString() ?? '—',
              senderRole: m['senderRole']?.toString() ?? '',
              senderPhone: m['senderPhone']?.toString() ?? '',
              requestType: m['requestType']?.toString() ?? 'cover',
              requestTime: m['requestTime']?.toString() ?? '',
              shiftName: m['shiftName']?.toString() ?? '—',
              shiftTime: m['shiftTime']?.toString() ?? '—',
              shiftHours: m['shiftHours']?.toString() ?? '',
              shiftDate: m['shiftDate']?.toString() ?? '—',
              branch: m['branch']?.toString() ?? '',
              shiftRole: m['shiftRole']?.toString() ?? '',
              swapShiftName: m['swapShiftName']?.toString(),
              swapShiftTime: m['swapShiftTime']?.toString(),
              swapShiftHours: m['swapShiftHours']?.toString(),
              swapShiftDate: m['swapShiftDate']?.toString(),
              swapShiftBranch: m['swapShiftBranch']?.toString(),
              swapShiftRole: m['swapShiftRole']?.toString(),
              reason: m['reason']?.toString() ?? '',
              initialStatus: m['initialStatus'] as ShiftRequestStatus? ?? ShiftRequestStatus.pending,
              onStatusChanged: m['onStatusChanged'] as Function(ShiftRequestStatus)?,
            );
          }
          return const SplashScreen();
        },
      ),
    ],
  );
}
