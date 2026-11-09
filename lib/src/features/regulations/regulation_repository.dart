import '../../core/network/api_client.dart';

class RegulationModel {
  final String id;
  final String code;
  final String title;
  final String category;
  final String summary;
  final String content;
  final String status;
  final String scope;
  final String effectiveDate;
  final String author;
  final String version;
  final bool pinned;

  const RegulationModel({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.status,
    required this.scope,
    required this.effectiveDate,
    required this.author,
    required this.version,
    this.pinned = false,
  });

  factory RegulationModel.fromJson(Map<String, dynamic> j) => RegulationModel(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        summary: j['summary']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        status: j['status']?.toString() ?? 'hiệu lực',
        scope: j['scope']?.toString() ?? 'Toàn công ty',
        effectiveDate: j['effectiveDate']?.toString() ?? '',
        author: j['author']?.toString() ?? '',
        version: j['version']?.toString() ?? '1.0',
        pinned: j['pinned'] == true,
      );
}

/// Repository nội quy gọi qua api-gateway về integration-service (4005).
class RegulationRepository {
  final ApiClient api;
  RegulationRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<RegulationModel>> getRegulations() async {
    final data = await api.getJson('/api/regulations');
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RegulationModel.fromJson)
        .toList();
  }

  Future<RegulationModel> createRegulation({
    required String title,
    required String category,
    required String content,
    String? summary,
    String? scope,
    String? author,
    String? status,
    String? effectiveDate,
    String? version,
    bool pinned = false,
  }) async {
    final payload = {
      'title': title,
      'category': category,
      'content': content,
      'summary': summary ?? (content.length > 90 ? '${content.substring(0, 90)}...' : content),
      'scope': scope ?? 'Toàn công ty',
      'status': status ?? 'hiệu lực',
      if (effectiveDate != null && effectiveDate.isNotEmpty) 'effectiveDate': effectiveDate,
      if (version != null && version.isNotEmpty) 'version': version,
      'pinned': pinned,
      if (author != null && author.isNotEmpty) 'author': author,
    };
    final data = await api.postJson('/api/regulations', payload);
    return RegulationModel.fromJson(data is Map<String, dynamic> ? data : {});
  }
}
