import '../models/user.dart';

/// Bảng phân quyền tính năng của app di động — nguồn chuẩn duy nhất, soi theo
/// `MENUS` trong frontend/src/lib/permissions.tsx.
///
/// Mỗi vai trò được liệt kê tường minh cho từng tuyến, không suy ra từ "không
/// phải admin", nên staff không bao giờ inherit tuyến của manager. Tuyến không
/// có trong bảng là luồng tự phục vụ (mọi vai trò đã đăng nhập): chấm công,
/// đăng ký ca, nghỉ phép, phiếu lương của chính mình, bảng tin, nội quy.
///
/// Luồng web/mobile lệch nhau ở một điểm có chủ đích: staff chỉ dùng app di
/// động (web chặn đăng nhập), nên phần tự phục vụ của staff rộng hơn STAFF_MENU
/// trên web; các tính năng quản trị thì ẩn đúng như web.
const Map<String, Set<String>> kRoleRestrictedRoutes = {
  '/tasks/monitor': {'admin', 'manager'},
  '/approvals': {'admin', 'manager'},
  '/schedule/assignment': {'admin', 'manager'},
  // Web coi cấu hình Wi-Fi là tính năng hệ thống (chỉ admin), manager không
  // thấy mục này trong menu.
  '/wifi': {'admin'},
};

const Map<String, String> kRoleLabels = {
  'admin': 'Quản trị viên',
  'manager': 'Quản lý Chi nhánh',
  'staff': 'Nhân viên',
};

const Set<String> _allRoles = {'admin', 'manager', 'staff'};

/// Chuỗi `role` tự do trên hồ sơ nhân sự ("Trưởng phòng", "Kế toán") chỉ là nhãn
/// chức danh; vai trò thật chỉ có 3 giá trị, còn lại quy về staff.
String normalizeRole(String? role) =>
    role == 'admin' || role == 'manager' ? role! : 'staff';

/// Tài khoản chưa resolve được phiên bị coi là staff (mức quyền thấp nhất)
/// thay vì mở quyền.
String roleOf(UserModel? user) => normalizeRole(user?.role);

Set<String> rolesAllowedFor(String route) => kRoleRestrictedRoutes[route] ?? _allRoles;

bool canAccessRoute(UserModel? user, String route) =>
    rolesAllowedFor(route).contains(roleOf(user));

/// Nhãn quyền dùng cho câu báo không có quyền, giữ đúng thứ tự khai báo.
String _roleLabelsFor(Set<String> roles) =>
    roles.map((r) => kRoleLabels[r] ?? r).join(' và ');

String permissionHintFor(String route) {
  final roles = kRoleRestrictedRoutes[route];
  if (roles == null) return 'Chức năng này không khả dụng với tài khoản của bạn.';
  return 'Chức năng này chỉ dành cho ${_roleLabelsFor(roles)}.';
}
