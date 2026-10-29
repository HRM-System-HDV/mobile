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
        author: j['author']?.toString() ?? 'Ban Quản trị',
        date: j['date']?.toString() ?? '',
        tag: j['tag']?.toString() ?? 'Thông báo',
        tagColor: _mapToneToColor(j['tagTone']?.toString()),
      );
    }).toList();
  }
}
