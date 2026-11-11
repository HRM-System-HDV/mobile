/// Mô hình người dùng cho hệ thống HRM On-Premises.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin', 'manager', 'staff'
  final String roleTitle;

  /// Chi nhánh được gán cho nhân sự (Admin và Manager cũng thuộc chi nhánh/HQ).
  final String? assignedBranchId;
  final String? branchSlug;

  /// Thông tin cá nhân & Địa chỉ cư trú (đồng bộ hệ thống)
  final String gender;
  final String birthDate;
  final String province;
  final String ward;
  final String street;

  /// Thông tin Căn cước công dân (CCCD)
  final String cccd;
  final String issueDate;
  final String issuePlace;

  /// Cấu hình tính lương & Tài khoản ngân hàng
  final String salaryType; // 'hourly' (Lương theo giờ) hoặc 'monthly' (Lương cơ bản tháng)
  final double hourlySalary; // VNĐ/giờ (khi checkout ca sẽ nhân số giờ làm)
  final double baseSalary; // VNĐ/tháng (cố định, checkout không cộng giờ, chỉ trừ khi phạt)
  final String bankName; // Tên ngân hàng nhận lương
  final String bankAccountNumber; // Số tài khoản ngân hàng
  final String bankAccountName; // Tên chủ tài khoản

  /// Hình ảnh xác thực (lưu trữ nội bộ)
  final String? avatarUrl;
  final String? cccdFrontUrl;
  final String? cccdBackUrl;

  const UserModel({
    this.id = '',
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    required this.roleTitle,
    this.assignedBranchId,
    this.branchSlug,
    this.gender = '',
    this.birthDate = '',
    this.province = '',
    this.ward = '',
    this.street = '',
    this.cccd = '',
    this.issueDate = '',
    this.issuePlace = '',
    this.salaryType = 'hourly',
    this.hourlySalary = 0.0,
    this.baseSalary = 0.0,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.avatarUrl,
    this.cccdFrontUrl,
    this.cccdBackUrl,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
  bool get canManage => isAdmin || isManager;
  bool get isHourlySalary => salaryType == 'hourly';

  /// `null` ở các trường tham chiếu có nghĩa là "giữ nguyên giá trị cũ".
  UserModel copyWith({
    String? name,
    String? phone,
    String? roleTitle,
    String? assignedBranchId,
    String? branchSlug,
    String? gender,
    String? birthDate,
    String? province,
    String? ward,
    String? street,
    String? cccd,
    String? issueDate,
    String? issuePlace,
    String? salaryType,
    double? hourlySalary,
    double? baseSalary,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? avatarUrl,
    String? cccdFrontUrl,
    String? cccdBackUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      roleTitle: roleTitle ?? this.roleTitle,
      assignedBranchId: assignedBranchId ?? this.assignedBranchId,
      branchSlug: branchSlug ?? this.branchSlug,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      province: province ?? this.province,
      ward: ward ?? this.ward,
      street: street ?? this.street,
      cccd: cccd ?? this.cccd,
      issueDate: issueDate ?? this.issueDate,
      issuePlace: issuePlace ?? this.issuePlace,
      salaryType: salaryType ?? this.salaryType,
      hourlySalary: hourlySalary ?? this.hourlySalary,
      baseSalary: baseSalary ?? this.baseSalary,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      cccdFrontUrl: cccdFrontUrl ?? this.cccdFrontUrl,
      cccdBackUrl: cccdBackUrl ?? this.cccdBackUrl,
    );
  }
}
