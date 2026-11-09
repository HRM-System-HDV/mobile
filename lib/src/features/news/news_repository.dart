import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'news.dart';

/// Repository bảng tin gọi qua api-gateway về integration-service (4005).
class NewsRepository {
  final ApiClient api;
  NewsRepository({ApiClient? api}) : api = api ?? ApiClient();

  Color _mapToneToColor(String? tone) {
    switch (tone) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'primary':
        return Colors.blue;
      case 'gray':
      default:
        return Colors.grey;
    }
  }

  Future<List<NewsArticle>> getNews() async {
    final data = await api.getJson('/api/news');
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().map((j) {
      return NewsArticle(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        summary: j['summary']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        author: j['author']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        tag: j['tag']?.toString() ?? 'Thông báo',
        tagColor: _mapToneToColor(j['tagTone']?.toString()),
        pinned: j['pinned'] == true,
        branch: j['branch']?.toString() ?? 'Toàn công ty',
      );
    }).toList();
  }

  Future<NewsArticle> createNews({
    required String title,
    required String content,
    String? summary,
    String? tag,
    String? tagTone,
    bool pinned = false,
    String? branch,
    String? author,
  }) async {
    final payload = {
      'title': title,
      'content': content,
      'summary': summary ?? (content.length > 90 ? '${content.substring(0, 90)}...' : content),
      'tag': tag ?? 'Thông báo',
      'tagTone': tagTone ?? 'primary',
      'pinned': pinned,
      'branch': branch ?? 'Toàn công ty',
      if (author != null && author.isNotEmpty) 'author': author,
    };
    final data = await api.postJson('/api/news', payload);
    final j = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return NewsArticle(
      id: j['id']?.toString() ?? 'n-${DateTime.now().millisecondsSinceEpoch}',
      title: j['title']?.toString() ?? title,
      summary: j['summary']?.toString() ?? (summary ?? content),
      content: j['content']?.toString() ?? content,
      author: j['author']?.toString() ?? (author ?? ''),
      date: j['date']?.toString() ?? '',
      tag: j['tag']?.toString() ?? (tag ?? 'Thông báo'),
      tagColor: _mapToneToColor(j['tagTone']?.toString() ?? tagTone),
      pinned: j['pinned'] == true,
      branch: j['branch']?.toString() ?? (branch ?? 'Toàn công ty'),
    );
  }
}
