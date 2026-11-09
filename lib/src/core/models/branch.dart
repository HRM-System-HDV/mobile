/// Chi nhánh doanh nghiệp trong hệ thống HRM On-Premises.
class Branch {
  final String id;
  final String slug; // khớp branchSlug trên Web Portal (VD: CN01)
  final String code; // mã rút gọn (VD: CN01)
  final String name;
  final String address;

  const Branch({
    required this.id,
    required this.slug,
    required this.code,
    required this.name,
    required this.address,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final slug = json['slug']?.toString() ?? json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? slug.toUpperCase();
    final name = json['name']?.toString() ?? (code.isNotEmpty ? 'Chi nhánh $code' : 'Chi nhánh');
    return Branch(
      id: json['id']?.toString() ?? slug,
      slug: slug,
      code: code,
      name: name,
      address: json['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'code': code,
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

/// Lấy branch theo id hoặc slug từ cache hoặc khởi tạo branch tạm thời khớp với slug/id
Branch branchById(String idOrSlug) {
  final query = idOrSlug.trim();
  final lower = query.toLowerCase();

  for (final b in _cachedBranches) {
    if (b.id == query || b.slug.toLowerCase() == lower || b.code.toLowerCase() == lower) {
      return b;
    }
  }

  // Nếu chưa có trong cache, tạo Branch động với slug/id đó thay vì mock dữ liệu giả
  final code = query.toUpperCase();
  return Branch(
    id: query,
    slug: query,
    code: code,
    name: code.isNotEmpty ? 'Chi nhánh $code' : 'Chi nhánh',
    address: '',
  );
}
