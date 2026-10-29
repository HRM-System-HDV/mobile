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
}
