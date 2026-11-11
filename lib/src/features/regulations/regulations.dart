import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../profile/employee_repository.dart';
import 'regulation_repository.dart';

class CompanyRegulationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const CompanyRegulationsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<CompanyRegulationsScreen> createState() => _CompanyRegulationsScreenState();
}

class _CompanyRegulationsScreenState extends State<CompanyRegulationsScreen> {
  final RegulationRepository _repo = RegulationRepository();
  final EmployeeRepository _empRepo = EmployeeRepository();
  List<RegulationModel> _apiRegulations = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRegulations();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final bList = await _empRepo.getBranches();
      if (mounted) setState(() => _branches = bList);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Không kết nối được máy chủ';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Không tải được danh sách chi nhánh: $msg'),
        ),
      );
    }
  }

  Future<void> _loadRegulations() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getRegulations();
      if (mounted) {
        setState(() {
          _apiRegulations = list;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e is ApiException ? e.message : 'Không kết nối được máy chủ';
        });
      }
    }
  }

  Color _colorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kỷ luật') || lower.contains('phạt') || lower.contains('khẩn')) {
      return Colors.red;
    }
    if (lower.contains('an toàn') || lower.contains('pccc') || lower.contains('bảo hộ')) {
      return Colors.orange;
    }
    if (lower.contains('thời gian') || lower.contains('giờ giấc') || lower.contains('chấm công')) {
      return Colors.teal;
    }
    if (lower.contains('thưởng') || lower.contains('phúc lợi') || lower.contains('lương')) {
      return Colors.green;
    }
    if (lower.contains('bảo mật') || lower.contains('dữ liệu')) {
      return Colors.indigo;
    }
    if (lower.contains('văn hóa') || lower.contains('tác phong') || lower.contains('ứng xử')) {
      return AppColors.primary;
    }
    return Colors.blue;
  }

  void _showDetail(BuildContext context, RegulationModel regulation) {
    final tagColor = _colorForCategory(regulation.category);
    final categoryText = regulation.category.isNotEmpty ? regulation.category : 'Nội quy';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      categoryText,
                      style: TextStyle(color: tagColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (regulation.pinned) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 12, color: Colors.amber),
                          SizedBox(width: 3),
                          Text('Đã ghim', style: TextStyle(color: Colors.brown, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  if (regulation.scope.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        regulation.scope,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                regulation.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Mã: ${regulation.code.isNotEmpty ? regulation.code : '—'} • Trạng thái: ${regulation.status} • Bản: v${regulation.version}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                toVnDate(regulation.effectiveDate).isEmpty
                    ? (regulation.author.isNotEmpty ? 'Ban hành bởi: ${regulation.author}' : '')
                    : (regulation.author.isNotEmpty
                        ? 'Ban hành bởi: ${regulation.author} • Hiệu lực: ${toVnDate(regulation.effectiveDate)}'
                        : 'Hiệu lực: ${toVnDate(regulation.effectiveDate)}'),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                regulation.content.isNotEmpty ? regulation.content : regulation.summary,
                style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRegulationModal() {
    final titleCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final effectiveDateCtrl = TextEditingController(
      text: vnDate(DateTime.now()),
    );
    final versionCtrl = TextEditingController(text: '1.0');
    String selectedCategory = 'Nội quy lao động';
    String selectedScope = 'Toàn công ty';
    String selectedStatus = 'hiệu lực';
    bool isPinned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tạo văn bản nội quy mới',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // 1. Tiêu đề quy định *
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề quy định *',
                    hintText: 'VD: Quy định về bảo hộ lao động và vệ sinh...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // 2. Danh mục quy định
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Danh mục quy định',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Nội quy lao động', child: Text('📋 Nội quy lao động')),
                    DropdownMenuItem(value: 'Chấm công & Kỷ luật', child: Text('⏰ Chấm công & Kỷ luật')),
                    DropdownMenuItem(value: 'Thưởng & Kỷ luật', child: Text('🏆 Thưởng & Kỷ luật')),
                    DropdownMenuItem(value: 'An toàn lao động', child: Text('🦺 An toàn lao động')),
                    DropdownMenuItem(value: 'Bảo mật & Dữ liệu', child: Text('🔒 Bảo mật & Dữ liệu')),
                    DropdownMenuItem(value: 'Vận hành chung', child: Text('⚙️ Vận hành chung')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                // 3. Phạm vi áp dụng
                DropdownButtonFormField<String>(
                  initialValue: selectedScope,
                  decoration: InputDecoration(
                    labelText: 'Phạm vi áp dụng',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'Toàn công ty', child: Text('🏢 Toàn công ty')),
                    ..._branches.map((b) => DropdownMenuItem(
                          value: b.code.toUpperCase(),
                          child: Text('🏬 Chi nhánh ${b.name} (${b.code.toUpperCase()})'),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedScope = val);
                  },
                ),
                const SizedBox(height: 12),
                // 4. Trạng thái & Ngày hiệu lực (Row 2 cột)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hiệu lực', child: Text('Đang hiệu lực')),
                          DropdownMenuItem(value: 'dự thảo', child: Text('Dự thảo')),
                          DropdownMenuItem(value: 'hết hiệu lực', child: Text('Hết hiệu lực')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: effectiveDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Ngày hiệu lực',
                          hintText: 'DD/MM/YYYY',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 5. Tóm tắt ngắn
                TextField(
                  controller: summaryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tóm tắt ngắn (hiển thị trên thẻ)',
                    hintText: 'Tóm tắt ngắn gọn 1-2 câu về mục tiêu...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // 6. Toàn văn điều khoản nội quy *
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Toàn văn điều khoản nội quy *',
                    hintText: 'Nhập chi tiết các chương, điều khoản, chế tài...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                // 7. Checkbox ghim lên đầu
                Row(
                  children: [
                    Checkbox(
                      value: isPinned,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() => isPinned = val ?? false);
                      },
                    ),
                    GestureDetector(
                      onTap: () => setModalState(() => isPinned = !isPinned),
                      child: const Text(
                        '📌 Ghim văn bản này lên đầu danh sách',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nút Ban hành
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đầy đủ tiêu đề và nội dung')),
                      );
                      return;
                    }

                    try {
                      final created = await _repo.createRegulation(
                        title: titleCtrl.text.trim(),
                        category: selectedCategory,
                        content: contentCtrl.text.trim(),
                        summary: summaryCtrl.text.trim().isNotEmpty ? summaryCtrl.text.trim() : null,
                        scope: selectedScope,
                        status: selectedStatus,
                        effectiveDate: toVnDate(effectiveDateCtrl.text.trim()),
                        version: versionCtrl.text.trim(),
                        pinned: isPinned,
                        author: '${widget.currentUser.name} (${widget.currentUser.roleTitle})',
                      );

                      if (sheetCtx.mounted) {
                        Navigator.pop(sheetCtx);
                      }
                      if (mounted) {
                        setState(() {
                          _apiRegulations.insert(0, created);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Đã ban hành nội quy mới thành công!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      // Không tạo nội quy cục bộ khi API lỗi; giữ sheet mở để không mất bản nháp.
                      if (!mounted) return;
                      final msg = e is ApiException ? e.message : 'Không kết nối được máy chủ. Vui lòng thử lại.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.error,
                          content: Text('❌ Tạo nội quy thất bại: $msg'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Ban hành nội quy ngay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.currentUser.canManage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nội quy & Quy định', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _showCreateRegulationModal,
              backgroundColor: AppColors.primary,
              icon: const FaIcon(FontAwesomeIcons.gavel, color: Colors.white),
              label: const Text('Tạo nội quy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadRegulations,
        color: AppColors.primary,
        child: _isLoading && _apiRegulations.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : _apiRegulations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(
                              _loadError != null ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.gavel,
                              size: 48,
                              color: _loadError != null ? AppColors.error : Colors.grey,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _loadError != null
                                  ? 'Không tải được nội quy: $_loadError'
                                  : 'Chưa có nội quy nào',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            if (_loadError != null) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Kéo xuống để thử lại',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: _apiRegulations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = _apiRegulations[index];
                      final tagColor = _colorForCategory(r.category);
                      final categoryText = r.category.isNotEmpty ? r.category : 'Nội quy';

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => _showDetail(context, r),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: tagColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            categoryText,
                                            style: TextStyle(color: tagColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (r.pinned) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.push_pin, size: 13, color: Colors.amber),
                                        ],
                                      ],
                                    ),
                                    if (r.scope.isNotEmpty)
                                      Text(
                                        r.scope,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r.title,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.summary.isNotEmpty ? r.summary : r.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (r.author.isNotEmpty) ...[
                                      const FaIcon(FontAwesomeIcons.user, size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(r.author, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ] else if (r.effectiveDate.isNotEmpty) ...[
                                      const FaIcon(FontAwesomeIcons.calendar, size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(toVnDate(r.effectiveDate), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                    const Spacer(),
                                    const Text('Chi tiết', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    const FaIcon(FontAwesomeIcons.chevronRight, size: 14, color: AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
