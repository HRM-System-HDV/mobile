import '../../core/network/api_client.dart';

class RegulationModel {
  final String id;
  final String regulationCode;
  final String title;
  final String category;
  final String summary;
  final String content;
  final String status;
  final String? scopeBranchId;
  final String effectiveDate;
  final String? expiryDate;
  final String version;
  final bool pinned;

  const RegulationModel({
    required this.id,
    required this.regulationCode,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.status,
    required this.scopeBranchId,
    required this.effectiveDate,
    required this.version,
    this.expiryDate,
    this.pinned = false,
  });

  factory RegulationModel.fromJson(Map<String, dynamic> j) => RegulationModel(
        id: j['id']?.toString() ?? '',
        regulationCode: j['regulationCode']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        summary: j['summary']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        status: j['status']?.toString() ?? 'hiệu lực',
        scopeBranchId: j['scopeBranchId']?.toString(),
        effectiveDate: j['effectiveDate']?.toString() ?? '',
        expiryDate: j['expiryDate']?.toString(),
        version: j['version']?.toString() ?? '1.0',
        pinned: j['pinned'] == true,
      );
}

/// Repository nội quy gọi qua api-gateway về integration-service (4005).
///
/// Hợp đồng ghi: `contentFields.regulation` = regulationCode, title, category,
/// summary, content, status, scopeBranchId (UUID), effectiveDate, expiryDate,
/// version, pinned. Bắt buộc có giá trị: regulationCode, title, category,
/// summary, content, effectiveDate; ngày phải theo định dạng yyyy-MM-dd.
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
    required String regulationCode,
    required String effectiveDate,
    String? summary,
    String? scopeBranchId,
    String? status,
    String? expiryDate,
    String? version,
    bool pinned = false,
  }) async {
    final body = content.trim();
    final payload = <String, dynamic>{
      'regulationCode': regulationCode,
      'title': title,
      'category': category,
      'summary': (summary != null && summary.isNotEmpty)
          ? summary
          : (body.length > 90 ? '${body.substring(0, 90)}...' : body),
      'content': body,
      'status': (status != null && status.isNotEmpty) ? status : 'hiệu lực',
      'effectiveDate': effectiveDate,
      'version': (version != null && version.isNotEmpty) ? version : '1.0',
      'pinned': pinned,
      if (expiryDate != null && expiryDate.isNotEmpty) 'expiryDate': expiryDate,
      if (scopeBranchId != null && scopeBranchId.isNotEmpty) 'scopeBranchId': scopeBranchId,
    };
    final data = await api.postJson('/api/regulations', payload);
    return RegulationModel.fromJson(
        data is Map<String, dynamic> ? data : const <String, dynamic>{});
  }
}
