import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import 'task_service.dart';

class ApiTaskModel {
  final String id;
  final String title;
  final String? description;
  final String? branchId;
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
  final String? templateId;
  final String? workDate;

  const ApiTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.branchId,
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
    this.templateId,
    this.workDate,
  });

  factory ApiTaskModel.fromJson(Map<String, dynamic> j) => ApiTaskModel(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString(),
        branchId: j['branchId']?.toString(),
        status: j['status']?.toString(),
        priority: j['priority']?.toString(),
        dueDate: j['dueDate']?.toString(),
        assigneeId: j['assignedTo']?.toString(),
        createdAt: j['createdAt']?.toString(),
        proofUrl: j['proofPhotoUrl']?.toString(),
        requirePhoto: j['requirePhoto'] == true,
        sourceType: j['sourceType']?.toString(),
        assignedByName: j['assignedByName']?.toString(),
        shiftName: j['shiftName']?.toString(),
        assignedToEmail: j['assignedToEmail']?.toString(),
        assignedToName: j['assignedToName']?.toString(),
        completedAt: j['completedAt']?.toString(),
        templateId: j['templateId']?.toString(),
        workDate: j['workDate']?.toString(),
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
      branch: branchId ?? '',
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

  Future<List<TaskModel>> getTasks({String? status, String? assigneeId, String? workDate}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (assigneeId != null && assigneeId.isNotEmpty) query['assignedTo'] = assigneeId;
    if (workDate != null && workDate.isNotEmpty) query['workDate'] = workDate;

    final data = await api.getJson('/api/tasks', query: query);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApiTaskModel.fromJson)
        .map((m) => m.toTaskModel())
        .toList();
  }

  /// Body chỉ được chứa đúng TASK_FIELDS của work-service; mọi key thừa đều 400.
  /// Việc cá nhân gửi `assignedTo` (employeeId UUID) — backend tự suy ra branchId.
  /// Việc chung để `assignedTo: null` kèm bắt buộc `branchId` + `templateId` + `workDate`.
  Future<void> createTask({
    required String title,
    String? description,
    String? assigneeId,
    String? branchId,
    String? templateId,
    String? workDate,
    String status = 'pending',
    String priority = 'normal',
    String? dueDate,
    bool requirePhoto = false,
  }) async {
    final isShared = assigneeId == null || assigneeId.isEmpty;
    await api.postJson('/api/tasks', {
      'title': title,
      if (description != null) 'description': description,
      'assignedTo': isShared ? null : assigneeId,
      if (isShared) 'branchId': branchId,
      if (isShared) 'templateId': templateId,
      if (isShared) 'workDate': workDate,
      'status': status,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate,
      'requirePhoto': requirePhoto,
    });
  }

  static String apiStatus(String status) {
    switch (status) {
      case 'completed':
        return 'done';
      case 'inProgress':
        return 'in_progress';
      default:
        return status;
    }
  }

  Future<void> updateTaskStatus(String id, String status, {String? proofUrl}) async {
    await api.putJson('/api/tasks/$id', {
      'status': apiStatus(status),
      if (proofUrl != null) 'proofPhotoUrl': proofUrl,
    });
  }

  Future<void> updateTask(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/tasks/$id', payload);
  }

  Future<void> deleteTask(String id) async {
    await api.delete('/api/tasks/$id');
  }
}
