import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
import '../../core/models/branch.dart';
import '../../core/network/api_client.dart';
import '../profile/employee_repository.dart';
import 'news_repository.dart';

class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String author;
  final String date;
  final String tag;
  final Color tagColor;
  final bool pinned;
  final String branch;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.author,
    required this.date,
    required this.tag,
    required this.tagColor,
    this.pinned = false,
    this.branch = 'Toàn công ty',
  });
}

class NewsScreen extends StatefulWidget {
  final UserModel currentUser;

  const NewsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsRepository _newsRepo = NewsRepository();
  final EmployeeRepository _empRepo = EmployeeRepository();
  List<NewsArticle> _articles = [];
  List<Branch> _branches = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchNews();
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

  Future<void> _fetchNews() async {
    try {
      final list = await _newsRepo.getNews();
      if (mounted) {
        setState(() {
          _articles = list;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e is ApiException ? e.message : 'Không kết nối được máy chủ';
        });
      }
    }
  }

  void _showDetail(BuildContext context, NewsArticle article) {
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
                      color: article.tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.tag,
                      style: TextStyle(color: article.tagColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (article.pinned) ...[
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
                  if (article.branch.isNotEmpty && article.branch != 'Toàn công ty') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.branch,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                article.author.isNotEmpty ? 'Đăng bởi: ${article.author} • ${article.date}' : 'Ngày đăng: ${article.date}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                article.content,
                style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateNewsModal() {
    final titleCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedTag = 'Thông báo';
    String selectedBranch = 'Toàn công ty';
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
                  'Đăng thông báo nội bộ mới',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // 1. Tiêu đề thông báo *
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề thông báo *',
                    hintText: 'VD: Thông báo kiểm kê chi nhánh, lịch nghỉ lễ...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // 2. Phân loại chuyên mục
                DropdownButtonFormField<String>(
                  initialValue: selectedTag,
                  decoration: InputDecoration(
                    labelText: 'Phân loại chuyên mục',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Thông báo', child: Text('📢 Thông báo chung')),
                    DropdownMenuItem(value: 'Khẩn cấp', child: Text('🚨 Thông báo khẩn (Tự động ghim)')),
                    DropdownMenuItem(value: 'Nghỉ lễ', child: Text('🏖️ Nghỉ lễ / Sự kiện')),
                    DropdownMenuItem(value: 'Khen thưởng', child: Text('🏆 Khen thưởng')),
                    DropdownMenuItem(value: 'Vận hành', child: Text('⚙️ Quy trình vận hành')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedTag = val;
                        if (val == 'Khẩn cấp') isPinned = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // 3. Chi nhánh áp dụng
                DropdownButtonFormField<String>(
                  initialValue: selectedBranch,
                  decoration: InputDecoration(
                    labelText: 'Chi nhánh áp dụng',
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
                    if (val != null) setModalState(() => selectedBranch = val);
                  },
                ),
                const SizedBox(height: 12),
                // 4. Tóm tắt ngắn
                TextField(
                  controller: summaryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tóm tắt ngắn (hiển thị trên thẻ)',
                    hintText: 'Nội dung tóm tắt trong 1-2 câu ngắn gọn...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // 5. Nội dung chi tiết *
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Nội dung chi tiết thông báo *',
                    hintText: 'Soạn thảo toàn văn nội dung thông báo gửi đến toàn thể nhân sự...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                // 6. Checkbox ghim lên đầu
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
                        '📌 Ghim thông báo này lên đầu danh sách',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nút Submit
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

                    String tagTone = 'primary';
                    if (selectedTag == 'Khẩn cấp') tagTone = 'danger';
                    if (selectedTag == 'Nghỉ lễ') tagTone = 'danger';
                    if (selectedTag == 'Khen thưởng') tagTone = 'warning';
                    if (selectedTag == 'Vận hành') tagTone = 'success';

                    try {
                      final created = await _newsRepo.createNews(
                        title: titleCtrl.text.trim(),
                        content: contentCtrl.text.trim(),
                        summary: summaryCtrl.text.trim().isNotEmpty ? summaryCtrl.text.trim() : null,
                        tag: selectedTag,
                        tagTone: tagTone,
                        pinned: isPinned,
                        branch: selectedBranch,
                        author: '${widget.currentUser.name} (${widget.currentUser.roleTitle})',
                      );

                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (mounted) {
                        setState(() {
                          _articles.insert(0, created);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Đã phát hành thông báo mới thành công!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      // Không tạo bản tin cục bộ khi API lỗi; giữ sheet mở để không mất bản nháp.
                      if (!mounted) return;
                      final msg = e is ApiException ? e.message : 'Không kết nối được máy chủ. Vui lòng thử lại.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.error,
                          content: Text('❌ Phát hành thông báo thất bại: $msg'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Phát hành thông báo ngay',
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
        title: const Text('Bảng tin & Thông báo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
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
              onPressed: _showCreateNewsModal,
              backgroundColor: AppColors.primary,
              icon: const FaIcon(FontAwesomeIcons.bullhorn, color: Colors.white),
              label: const Text('Đăng thông báo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _fetchNews,
        color: AppColors.primary,
        child: _articles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          _loadError != null ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.newspaper,
                          size: 48,
                          color: _loadError != null ? AppColors.error : Colors.grey,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _loadError != null
                              ? 'Không tải được bảng tin: $_loadError'
                              : 'Chưa có thông báo hoặc tin tức nào',
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
                itemCount: _articles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = _articles[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () => _showDetail(context, a),
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
                                        color: a.tagColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(a.tag, style: TextStyle(color: a.tagColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    ),
                                    if (a.pinned) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.push_pin, size: 13, color: Colors.amber),
                                    ],
                                  ],
                                ),
                                Text(a.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(a.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (a.author.isNotEmpty) ...[
                                  const FaIcon(FontAwesomeIcons.user, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(a.author, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
