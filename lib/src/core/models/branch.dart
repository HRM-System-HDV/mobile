/// Chi nhánh doanh nghiệp trong hệ thống HRM On-Premises.
///
/// organization-service trả `id, branchCode, name, address, status`; không còn
/// `slug`/`branchSlug` ở bất kỳ tầng nào, mọi filter theo chi nhánh dùng `id`
/// (UUID) của branch.
class Branch {
  final String id;

  /// Mã nghiệp vụ chi nhánh (VD: CN-00001) — đúng cột `branchCode` của backend.
  final String branchCode;
  final String name;
  final String address;

  const Branch({
    required this.id,
    required this.branchCode,
    required this.name,
    required this.address,
  });

  /// Nhãn ngắn dùng cho UI (viết hoa, lọc cache...).
  String get code => branchCode;

  factory Branch.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final branchCode = json['branchCode']?.toString() ?? id;
    final name = json['name']?.toString() ??
        (branchCode.isNotEmpty ? 'Chi nhánh $branchCode' : 'Chi nhánh');
    return Branch(
      id: id,
      branchCode: branchCode,
      name: name,
      address: json['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'branchCode': branchCode,
        'name': name,
        'address': address,
      };
}

/// Cache danh sách chi nhánh được tải từ API / DB thật
List<Branch> _cachedBranches = [];

/// Cập nhật cache chi nhánh thật
void updateBranchCache(List<Branch> branches) {
  _cachedBranches = List.unmodifiable(branches);
}

/// Lấy danh sách chi nhánh đã tải từ server
List<Branch> get branches => _cachedBranches;

/// Lấy branch theo id hoặc branchCode từ cache; không có trong cache thì trả
/// đối tượng tạm mang đúng id đó (không bịa tên chi nhánh).
Branch branchById(String idOrCode) {
  final query = idOrCode.trim();
  final lower = query.toLowerCase();

  for (final b in _cachedBranches) {
    if (b.id == query || b.branchCode.toLowerCase() == lower) {
      return b;
    }
  }

  return Branch(
    id: query,
    branchCode: query,
    name: query,
    address: '',
  );
}
