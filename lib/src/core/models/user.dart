/// Mô hình người dùng cho hệ thống HRM On-Premises.
///
/// Phần tài khoản lấy đúng từ `toSafeUser` của identity-service:
/// `id, employeeId, email, name, systemRole, role, branchId`.
/// `employeeId` là UUID nhân sự mà mọi service nghiệp vụ (work/payroll) cần;
/// `id` chỉ là id tài khoản và không được dùng thay cho `employeeId`.
///
/// Phần còn lại là cache hồ sơ organization-service (`EmployeeRepository`) mà
/// màn Tài khoản nạp và cho chính nhân viên tự sửa.
class UserModel {
  final String id;

  /// UUID hồ sơ nhân sự trong organization-service; null với tài khoản chưa gán.
  final String? employeeId;
  final String name;
  final String email;

  /// Vai trò hệ thống: quyền quyết định là `systemRole` phía backend, `role`
  /// chỉ còn là fallback cho dữ liệu cũ.
  final String role; // 'admin', 'manager', 'staff'

  /// Chi nhánh được gán cho nhân sự (Admin và Manager cũng thuộc chi nhánh/HQ).
  final String? assignedBranchId;

  /// Hồ sơ nhân sự do organization-service trả (`EmployeeRepository`), nằm
  /// trong `selfFields` nên chính nhân viên được đọc/ghi: `phone`, `avatar`,
  /// `cccdFront`. `toSafeUser` không có các trường này nên chúng rỗng cho tới
  /// khi màn Tài khoản nạp hồ sơ.
  final String phone;
  final String gender;
  final String birthDate;
  final String province;
  final String ward;
  final String street;

  /// Thông tin Căn cước công dân (CCCD)
  final String cccd;
  final String issueDate;
  final String issuePlace;
  final String? cccdFrontUrl;
  final String? cccdBackUrl;

  /// Đường dẫn ảnh đại diện (cột `avatar` của Employee).
  final String? avatarUrl;

  /// Cấu hình tính lương & Tài khoản ngân hàng
  final String salaryType; // 'hourly' (Lương theo giờ) hoặc 'monthly' (Lương cơ bản tháng)
  final String bankName; // Tên ngân hàng nhận lương
  final String bankAccountNumber; // Số tài khoản ngân hàng
  final String bankAccountName; // Tên chủ tài khoản

  const UserModel({
    this.id = '',
    this.employeeId,
    required this.name,
    required this.email,
    required this.role,
    this.assignedBranchId,
    this.phone = '',
    this.gender = '',
    this.birthDate = '',
    this.province = '',
    this.ward = '',
    this.street = '',
    this.cccd = '',
    this.issueDate = '',
    this.issuePlace = '',
    this.cccdFrontUrl,
    this.cccdBackUrl,
    this.avatarUrl,
    this.salaryType = 'hourly',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
  bool get canManage => isAdmin || isManager;
  bool get isHourlySalary => salaryType == 'hourly';

  /// `null` ở các trường tham chiếu có nghĩa là "giữ nguyên giá trị cũ".
  UserModel copyWith({
    String? employeeId,
    String? name,
    String? role,
    String? assignedBranchId,
    String? phone,
    String? gender,
    String? birthDate,
    String? province,
    String? ward,
    String? street,
    String? cccd,
    String? issueDate,
    String? issuePlace,
    String? cccdFrontUrl,
    String? cccdBackUrl,
    String? avatarUrl,
    String? salaryType,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) {
    return UserModel(
      id: id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email,
      role: role ?? this.role,
      assignedBranchId: assignedBranchId ?? this.assignedBranchId,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      province: province ?? this.province,
      ward: ward ?? this.ward,
      street: street ?? this.street,
      cccd: cccd ?? this.cccd,
      issueDate: issueDate ?? this.issueDate,
      issuePlace: issuePlace ?? this.issuePlace,
      cccdFrontUrl: cccdFrontUrl ?? this.cccdFrontUrl,
      cccdBackUrl: cccdBackUrl ?? this.cccdBackUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      salaryType: salaryType ?? this.salaryType,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }
}
