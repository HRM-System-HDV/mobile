import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

enum TaskSourceType {
  manager, // Quản lý giao riêng
  shift,   // Cố định theo ca
}

enum TaskStatus {
  pending,    // Cần thực hiện
  inProgress, // Đang làm (giữ enum cho backward compatibility nếu có)
  overdue,    // Quá giờ
  completed,  // Đã xong
}

enum TaskPriority {
  urgent, // Khẩn cấp
  high,   // Quan trọng
  normal, // Bình thường
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskSourceType sourceType;
  final String assignedByName; // Tên quản lý hoặc người giao
  final String? shiftName;     // Ca gắn liền (nếu có)
  final String branch;
  final DateTime dueDate;
  TaskStatus status;
  final TaskPriority priority;
  final String? assignedToEmail;
  final String? assignedToName;
  DateTime? completedAt;
  final bool requirePhoto;      // Quản trị viên yêu cầu chụp ảnh kết quả
  String? proofPhotoUrl;        // Ảnh chụp minh chứng kết quả công việc

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceType,
    required this.assignedByName,
    this.shiftName,
    required this.branch,
    required this.dueDate,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.normal,
    this.assignedToEmail,
    this.assignedToName,
    this.completedAt,
    this.requirePhoto = false,
    this.proofPhotoUrl,
  });

  bool get isOverdue {
    if (status == TaskStatus.completed) return false;
    return DateTime.now().isAfter(dueDate);
  }

  TaskStatus get computedStatus {
    if (status == TaskStatus.completed) return TaskStatus.completed;
    if (status == TaskStatus.inProgress) return TaskStatus.inProgress;
    if (isOverdue) return TaskStatus.overdue;
    return TaskStatus.pending;
  }

  String get sourceLabel => sourceType == TaskSourceType.manager
      ? 'Quản lý giao riêng'
      : 'Cố định theo ca';

  String get shortSourceLabel => sourceType == TaskSourceType.manager
      ? 'Giao riêng'
      : 'Theo ca';

  IconData get sourceIcon => sourceType == TaskSourceType.manager
      ? Icons.push_pin_rounded
      : Icons.sync_rounded;

  Color get sourceColor => sourceType == TaskSourceType.manager
      ? AppColors.primary
      : const Color(0xFF2563EB);

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.urgent:
        return 'Khẩn cấp';
      case TaskPriority.high:
        return 'Quan trọng';
      case TaskPriority.normal:
        return 'Bình thường';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.urgent:
        return const Color(0xFFDC2626);
      case TaskPriority.high:
        return const Color(0xFFEA580C);
      case TaskPriority.normal:
        return const Color(0xFF64748B);
    }
  }

  String get statusLabel {
    switch (computedStatus) {
      case TaskStatus.completed:
        return 'Đã xong';
      case TaskStatus.inProgress:
        return 'Đang làm';
      case TaskStatus.overdue:
        return 'Quá giờ';
      case TaskStatus.pending:
        return 'Cần thực hiện';
    }
  }

  Color get statusColor {
    switch (computedStatus) {
      case TaskStatus.completed:
        return AppColors.success;
      case TaskStatus.inProgress:
        return const Color(0xFFF59E0B);
      case TaskStatus.overdue:
        return const Color(0xFFDC2626);
      case TaskStatus.pending:
        return const Color(0xFF3B82F6);
    }
  }
}

class TaskService {
  /// Danh sách việc chỉ lấy từ API thật qua [TaskRepository].
  /// Không còn mock fallback — trả về [] để UI hiện empty state.
  /// TODO: nối API phân trang/lọc theo userEmail khi work-service hỗ trợ.
  static List<TaskModel> getTasksForUser({String? userEmail}) {
    return const [];
  }

  /// Cập nhật trạng thái công việc — TODO: nối API thật (hiện no-op,
  /// màn hình gọi TaskRepository.updateTaskStatus rồi _loadTasks lại).
  static void updateTaskStatus(String taskId, TaskStatus newStatus, {String? proofPhotoUrl}) {}

  /// Hoàn thành công việc kèm ảnh minh chứng (nếu có) — TODO: nối API thật.
  static void completeTask(String taskId, {String? proofPhotoUrl}) {}

  /// Thêm công việc mới — TODO: nối API thật qua TaskRepository.createTask.
  static void addTask(TaskModel newTask) {}

  /// Thống kê số lượng việc từ danh sách API thật đã load ở UI.
  static Map<String, int> getTaskStats({List<TaskModel> tasks = const []}) {
    int total = tasks.length;
    int pending = 0;
    int inProgress = 0;
    int overdue = 0;
    int completed = 0;

    for (final t in tasks) {
      switch (t.computedStatus) {
        case TaskStatus.pending:
          pending++;
          break;
        case TaskStatus.inProgress:
          inProgress++;
          break;
        case TaskStatus.overdue:
          overdue++;
          break;
        case TaskStatus.completed:
          completed++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'inProgress': inProgress,
      'overdue': overdue,
      'completed': completed,
    };
  }
}
