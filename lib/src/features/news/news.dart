import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
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

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.author,
    required this.date,
    required this.tag,
    required this.tagColor,
  });
}

class NewsScreen extends StatefulWidget {
  final UserModel currentUser;

  const NewsScreen({
    super.key,
    this.currentUser = const UserModel(
      name: 'Nguyễn Thu Hà',
      email: 'nhanvien@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ),
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsRepository _newsRepo = NewsRepository();

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final list = await _newsRepo.getNews();
      if (mounted) {
        setState(() {
          _articles = list;
        });
      }
    } catch (_) {
      // API lỗi thì giữ nguyên danh sách hiện tại (rỗng) để hiện empty state.
    }
  }

  List<NewsArticle> _articles = [];

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
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: article.tagColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(article.tag, style: TextStyle(color: article.tagColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              Text(article.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Đăng bởi: ${article.author} • ${article.date}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(article.content, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateNewsModal() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedTag = 'Thông báo';

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
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề thông báo *',
                    hintText: 'Ví dụ: Lịch kiểm kê định kỳ, khen thưởng...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTag,
                  decoration: InputDecoration(
                    labelText: 'Phân loại thông báo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Thông báo', child: Text('📢 Thông báo chung')),
                    DropdownMenuItem(value: 'Khẩn cấp', child: Text('🚨 Thông báo khẩn')),
                    DropdownMenuItem(value: 'Nghỉ lễ', child: Text('🏖️ Nghỉ lễ / Sự kiện')),
                    DropdownMenuItem(value: 'Khen thưởng', child: Text('🏆 Khen thưởng')),
                    DropdownMenuItem(value: 'Vận hành', child: Text('⚙️ Quy trình vận hành')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedTag = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Nội dung chi tiết *',
                    hintText: 'Nhập đầy đủ thông tin gửi tới toàn thể nhân viên...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đầy đủ tiêu đề và nội dung')),
                      );
                      return;
                    }

                    Color tagColor = Colors.blue;
                    if (selectedTag == 'Khẩn cấp') tagColor = Colors.red;
                    if (selectedTag == 'Nghỉ lễ') tagColor = Colors.orange;
                    if (selectedTag == 'Khen thưởng') tagColor = Colors.amber.shade800;
                    if (selectedTag == 'Vận hành') tagColor = Colors.teal;

                    final now = DateTime.now();
                    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

                    final newArticle = NewsArticle(
                      id: 'n-${DateTime.now().millisecondsSinceEpoch}',
                      title: titleCtrl.text.trim(),
                      summary: contentCtrl.text.trim().length > 90
                          ? '${contentCtrl.text.trim().substring(0, 90)}...'
                          : contentCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      author: '${widget.currentUser.name} (${widget.currentUser.roleTitle})',
                      date: dateStr,
                      tag: selectedTag,
                      tagColor: tagColor,
                    );

                    setState(() {
                      _articles.insert(0, newArticle);
                    });

                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Đã phát hành thông báo mới thành công!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Phát hành thông báo ngay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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
        title: const Text('Bảng tin nội bộ', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
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
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.newspaper, size: 48, color: Colors.grey),
                        SizedBox(height: 14),
                        Text('Chưa có thông báo hoặc tin tức nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: a.tagColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(a.tag, style: TextStyle(color: a.tagColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
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
                          const FaIcon(FontAwesomeIcons.user, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(a.author, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
