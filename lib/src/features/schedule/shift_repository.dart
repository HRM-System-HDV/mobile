import '../../core/network/api_client.dart';

class ApiShiftModel {
  final String id;
  final String? employeeId;
  final String? branchSlug;
  final String date;
  final String template;
  final String scheduledStart;
  final String scheduledEnd;
  final String status;
  final String? note;

  const ApiShiftModel({
    required this.id,
    this.employeeId,
    this.branchSlug,
    required this.date,
    required this.template,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.status = 'scheduled',
    this.note,
  });

  factory ApiShiftModel.fromJson(Map<String, dynamic> j) => ApiShiftModel(
        id: j['id']?.toString() ?? '',
        employeeId: j['employeeId']?.toString(),
        branchSlug: j['branchSlug']?.toString(),
        date: j['date']?.toString() ?? '',
        template: j['template']?.toString() ?? 'Ca làm việc',
        scheduledStart: j['scheduledStart']?.toString() ?? '08:00',
        scheduledEnd: j['scheduledEnd']?.toString() ?? '17:00',
        status: j['status']?.toString() ?? 'scheduled',
        note: j['note']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (employeeId != null) 'employeeId': employeeId,
        if (branchSlug != null) 'branchSlug': branchSlug,
        'date': date,
        'template': template,
        'scheduledStart': scheduledStart,
        'scheduledEnd': scheduledEnd,
        'status': status,
        if (note != null) 'note': note,
      };
}

/// Repository ca làm việc gọi qua api-gateway (4000) về work-service (4003).
class ShiftRepository {
  final ApiClient api;
  ShiftRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<ApiShiftModel>> getShifts({
    String? branchSlug,
    String? employeeId,
    String? date,
  }) async {
    final query = <String, String>{};
    if (branchSlug != null && branchSlug.isNotEmpty) query['branchSlug'] = branchSlug;
    if (employeeId != null && employeeId.isNotEmpty) query['employeeId'] = employeeId;
    if (date != null && date.isNotEmpty) query['date'] = date;

    final data = await api.getJson('/api/shifts', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiShiftModel.fromJson)
        .toList();
  }

  Future<ApiShiftModel> createShift(Map<String, dynamic> payload) async {
    final res = await api.postJson('/api/shifts', payload);
    final Map<String, dynamic> map = res is Map<String, dynamic> ? res : {};
    return ApiShiftModel.fromJson(map);
  }

  Future<void> updateShift(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/shifts/$id', payload);
  }

  Future<void> deleteShift(String id) async {
    await api.delete('/api/shifts/$id');
  }

  Future<void> assignShift(String id, {required String employeeId}) async {
    await api.postJson('/api/shifts/$id/assign', {'employeeId': employeeId});
  }

  Future<void> registerShift({
    required String employeeId,
    required String shiftId,
    String? preference,
  }) async {
    await api.postJson('/api/shifts/register', {
      'employeeId': employeeId,
      'shiftId': shiftId,
      if (preference != null) 'preference': preference,
    });
  }

  Future<List<Map<String, dynamic>>> getRegistrations({String? employeeId}) async {
    final query = <String, String>{};
    if (employeeId != null) query['employeeId'] = employeeId;
    final data = await api.getJson('/api/shifts/registrations', query: query);
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final data = await api.getJson('/api/shifts/templates');
    final List list = data is List ? data : [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    final res = await api.postJson('/api/shifts/templates', payload);
    return res is Map<String, dynamic> ? res : {};
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/shifts/templates/$id', payload);
  }

  Future<void> deleteTemplate(String id) async {
    await api.delete('/api/shifts/templates/$id');
  }
}
