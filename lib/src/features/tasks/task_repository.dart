import '../../core/network/api_client.dart';
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
  });

  factory ApiTaskModel.fromJson(Map<String, dynamic> j) => ApiTaskModel(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString(),
        branchSlug: j['branchSlug']?.toString(),
        status: j['status']?.toString(),
        priority: j['priority']?.toString(),
        dueDate: j['dueDate']?.toString(),
        assigneeId: j['assigneeId']?.toString(),
        createdAt: j['createdAt']?.toString(),
        proofUrl: j['proofUrl']?.toString() ?? j['proofPhotoUrl']?.toString(),
        requirePhoto: j['requirePhoto'] == true,
      );

  TaskModel toTaskModel() {
    final now = DateTime.now();
    DateTime parsedDueDate = now.add(const Duration(hours: 4));
    if (dueDate != null) {
      final parsed = DateTime.tryParse(dueDate!);
      if (parsed != null) parsedDueDate = parsed;
    }

    TaskPriority pri = TaskPriority.normal;
    if (priority == 'urgent' || priority == 'khẩn cấp') {
      pri = TaskPriority.urgent;
    } else if (priority == 'high' || priority == 'cao') {
      pri = TaskPriority.high;
    }

    TaskStatus st = TaskStatus.pending;
    if (status == 'completed' || status == 'đã xong') {
      st = TaskStatus.completed;
    } else if (status == 'in_progress' || status == 'đang làm') {
      st = TaskStatus.inProgress;
    }

    return TaskModel(
      id: id,
      title: title,
      description: description ?? '',
      sourceType: TaskSourceType.manager,
      assignedByName: 'Quản lý chi nhánh',
      branch: branchSlug ?? 'HN-1',
      dueDate: parsedDueDate,
      status: st,
      priority: pri,
      assignedToName: assigneeId != null ? 'Nhân viên #$assigneeId' : 'Bạn',
      requirePhoto: requirePhoto,
      proofPhotoUrl: proofUrl,
    );
  }
}

/// Repository tác vụ gọi qua api-gateway (4000) về work-service (4003).
class TaskRepository {
  final ApiClient api;
  TaskRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<TaskModel>> getTasks({String? branchSlug, String? status}) async {
    final query = <String, String>{};
    if (branchSlug != null && branchSlug.isNotEmpty) query['branchSlug'] = branchSlug;
    if (status != null && status.isNotEmpty) query['status'] = status;

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
  }) async {
    await api.postJson('/api/tasks', {
      'title': title,
      'description': description ?? '',
      'branchSlug': branchSlug,
      'status': status,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate,
      if (assigneeId != null) 'assigneeId': assigneeId,
    });
  }

  Future<void> updateTaskStatus(String id, String status, {String? proofUrl}) async {
    await api.putJson('/api/tasks/$id', {
      'status': status,
      if (proofUrl != null) 'proofUrl': proofUrl,
    });
  }

  Future<void> updateTask(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/tasks/$id', payload);
  }

  Future<void> deleteTask(String id) async {
    await api.delete('/api/tasks/$id');
  }
}
