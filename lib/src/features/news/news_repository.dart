import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'news.dart';

/// Repository bảng tin gọi qua api-gateway về integration-service (4005).
///
/// Hợp đồng ghi: `contentFields.news` = title, summary, content, publishDate,
/// tag, pinned, branchId — gửi khóa nào ngoài danh sách này là 400.
class NewsRepository {
  final ApiClient api;
  NewsRepository({ApiClient? api}) : api = api ?? ApiClient();

  /// Backend không lưu màu nhãn: màu suy từ chuyên mục theo đúng bảng màu màn hình tin.
  Color _colorForTag(String tag) {
    switch (tag) {
      case 'Khẩn cấp':
      case 'Nghỉ lễ':
        return Colors.red;
      case 'Khen thưởng':
        return Colors.orange;
      case 'Vận hành':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  NewsArticle _parse(Map<String, dynamic> j) {
    final tag = j['tag']?.toString() ?? 'Thông báo';
    final branchId = j['branchId']?.toString() ?? '';
    final publishDate = j['publishDate']?.toString() ?? '';
    return NewsArticle(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      summary: j['summary']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      author: j['authorName']?.toString() ?? '',
      date: publishDate,
      tag: tag,
      tagColor: _colorForTag(tag),
      pinned: j['pinned'] == true,
      branch: branchId.isEmpty ? 'Toàn công ty' : branchId,
    );
  }

  Future<NewsArticle> getNewsById(String id) async {
    final data = await api.getJson('/api/news/${Uri.encodeComponent(id)}');
    if (data is! Map<String, dynamic> || data['id'] != id) {
      throw const ApiException('INVALID_RESPONSE', 'Dữ liệu chi tiết không hợp lệ', 502);
    }
    return _parse(data);
  }

  Future<List<NewsArticle>> getNews() async {
    final data = await api.getJson('/api/news');
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().map(_parse).toList();
  }

  Future<NewsArticle> createNews({
    required String title,
    required String content,
    String? summary,
    String? tag,
    String? publishDate,
    bool pinned = false,
    String? branchId,
  }) async {
    final body = content.trim();
    final summaryText = (summary != null && summary.isNotEmpty)
        ? summary
        : (body.length > 90 ? '${body.substring(0, 90)}...' : body);
    final tagText = (tag != null && tag.isNotEmpty) ? tag : 'Thông báo';
    final payload = <String, dynamic>{
      'title': title,
      'summary': summaryText,
      'content': body,
      'publishDate': (publishDate != null && publishDate.isNotEmpty) ? publishDate : _today(),
      'tag': tagText,
      'pinned': pinned,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    };
    final data = await api.postJson('/api/news', payload);
    return _parse(data is Map<String, dynamic> ? data : const <String, dynamic>{});
  }
}
