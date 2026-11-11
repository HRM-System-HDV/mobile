import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import 'task_service.dart';

class ApiTaskModel {
  final String id;
  final String title;
  final String? description;
  final String? branchSlug;
  final String? status;
  final String? priority;
  final String? dueDate;
  final String? assigneeId;
  final String? createdAt;
  final String? proofUrl;
  final bool requirePhoto;
  final String? sourceType;
  final String? assignedByName;
  final String? shiftName;
  final String? assignedToEmail;
  final String? assignedToName;
  final String? completedAt;

  const ApiTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.branchSlug,
    this.status,
    this.priority,
    this.dueDate,
    this.assigneeId,
    this.createdAt,
    this.proofUrl,
    this.requirePhoto = false,
    this.sourceType,
    this.assignedByName,
    this.shiftName,
    this.assignedToEmail,
    this.assignedToName,
    this.completedAt,
  });

  factory ApiTaskModel.fromJson(Map<String, dynamic> j) => ApiTaskModel(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString(),
        branchSlug: j['branchSlug']?.toString(),
        status: j['status']?.toString(),
        priority: j['priority']?.toString(),
        dueDate: j['dueDate']?.toString(),
        assigneeId: j['assigneeId']?.toString() ?? j['assignedTo']?.toString(),
        createdAt: j['createdAt']?.toString(),
        proofUrl: j['proofUrl']?.toString() ?? j['proofPhotoUrl']?.toString(),
        requirePhoto: j['requirePhoto'] == true,
        sourceType: j['sourceType']?.toString(),
        assignedByName: j['assignedByName']?.toString(),
        shiftName: j['shiftName']?.toString(),
        assignedToEmail: j['assignedToEmail']?.toString(),
        assignedToName: j['assignedToName']?.toString(),
        completedAt: j['completedAt']?.toString(),
      );

  TaskModel toTaskModel() {
    // dueDate có thể là DD/MM/YYYY HH:mm (mới) hoặc ISO (dữ liệu cũ).
    final parsedDueDate = parseVnDate(dueDate);

    TaskPriority pri = TaskPriority.normal;
    if (priority == 'urgent' || priority == 'khẩn cấp') {
      pri = TaskPriority.urgent;
    } else if (priority == 'high' || priority == 'cao') {
      pri = TaskPriority.high;
    }

    TaskStatus st = TaskStatus.pending;
    if (status == 'completed' || status == 'done' || status == 'đã xong') {
      st = TaskStatus.completed;
    } else if (status == 'in_progress' || status == 'inProgress' || status == 'đang làm') {
      st = TaskStatus.inProgress;
    }

    final isShift = sourceType == 'shift' || (shiftName != null && shiftName!.isNotEmpty);

    final parsedCompletedAt = parseVnDate(completedAt);

    final desc = (description == null || description!.trim().isEmpty)
        ? 'Không có hướng dẫn'
        : description!.trim();

    return TaskModel(
      id: id,
      title: title,
      description: desc,
      sourceType: isShift ? TaskSourceType.shift : TaskSourceType.manager,
      assignedByName: assignedByName ?? '—',
      shiftName: shiftName,
      branch: branchSlug ?? '',
      dueDate: parsedDueDate,
      status: st,
      priority: pri,
      assignedToEmail: assignedToEmail,
      assignedToName: assignedToName ?? '—',
      completedAt: parsedCompletedAt,
      requirePhoto: requirePhoto,
      proofPhotoUrl: proofUrl,
    );
  }
}

/// Repository tác vụ gọi qua api-gateway (4000) về work-service (4003).
class TaskRepository {
  final ApiClient api;
  TaskRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<TaskModel>> getTasks({String? branchSlug, String? status, String? assigneeId}) async {
    final query = <String, String>{};
    if (branchSlug != null && branchSlug.isNotEmpty) query['branchSlug'] = branchSlug;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (assigneeId != null && assigneeId.isNotEmpty) query['assignedTo'] = assigneeId;

    final data = await api.getJson('/api/tasks', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiTaskModel.fromJson)
        .map((m) => m.toTaskModel())
        .toList();
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String branchSlug,
    String status = 'pending',
    String priority = 'normal',
    String? dueDate,
    String? assigneeId,
    String? sourceType,
    String? assignedByName,
    String? shiftName,
    String? assignedToEmail,
    String? assignedToName,
    bool requirePhoto = false,
  }) async {
    await api.postJson('/api/tasks', {
      'title': title,
      'description': description ?? '',
      'branchSlug': branchSlug,
      'status': status,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate,
      if (assigneeId != null) 'assignedTo': assigneeId,
      if (sourceType != null) 'sourceType': sourceType,
      if (assignedByName != null) 'assignedByName': assignedByName,
      if (shiftName != null) 'shiftName': shiftName,
      if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
      if (assignedToName != null) 'assignedToName': assignedToName,
      'requirePhoto': requirePhoto,
    });
  }

  Future<void> updateTaskStatus(String id, String status, {String? proofUrl, String? photoSubmittedBy}) async {
    final nowVn = vnDateTime(DateTime.now());
    await api.putJson('/api/tasks/$id', {
      'status': status,
      if (proofUrl != null) 'proofPhotoUrl': proofUrl,
      if (photoSubmittedBy != null) 'photoSubmittedBy': photoSubmittedBy,
      if (proofUrl != null) 'photoSubmittedAt': nowVn,
      if (status == 'completed' || status == 'done') 'completedAt': nowVn,
    });
  }

  Future<void> updateTask(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/tasks/$id', payload);
  }

  Future<void> deleteTask(String id) async {
    await api.delete('/api/tasks/$id');
  }
}
