import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/tasks/task_repository.dart';
import 'package:mobile/src/features/tasks/task_service.dart';

import 'mock_api_client.dart';

void main() {
  late MockApiClient mockApi;
  late TaskRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = TaskRepository(api: mockApi);
  });

  group('TaskRepository.getTasks', () {
    test('fetches and converts ApiTaskModel to TaskModel correctly', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'task-1',
          'title': 'Dọn quầy bar',
          'description': 'Lau sạch các máy pha chế',
          'branchSlug': 'q1',
          'status': 'in_progress',
          'priority': 'urgent',
          'dueDate': '15/11/2026 18:00',
          'assigneeId': 'emp-101',
          'assignedToName': 'Nguyễn Văn A',
          'assignedByName': 'Quản lý B',
          'sourceType': 'shift',
          'shiftName': 'Ca Chiều',
          'requirePhoto': true,
          'proofUrl': 'http://image.url/proof.jpg',
        },
        {
          'id': 'task-2',
          'title': 'Kiểm kê kho',
          'status': 'completed',
          'priority': 'high',
          'completedAt': '15/11/2026 20:00',
        }
      ];

      final tasks = await repository.getTasks(
        branchSlug: 'q1',
        status: 'in_progress',
        assigneeId: 'emp-101',
      );

      expect(tasks.length, 2);

      final t1 = tasks[0];
      expect(t1.id, 'task-1');
      expect(t1.title, 'Dọn quầy bar');
      expect(t1.status, TaskStatus.inProgress);
      expect(t1.priority, TaskPriority.urgent);
      expect(t1.sourceType, TaskSourceType.shift);
      expect(t1.shiftName, 'Ca Chiều');
      expect(t1.requirePhoto, true);
      expect(t1.proofPhotoUrl, 'http://image.url/proof.jpg');

      final t2 = tasks[1];
      expect(t2.id, 'task-2');
      expect(t2.status, TaskStatus.completed);
      expect(t2.priority, TaskPriority.high);

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.path, '/api/tasks');
      expect(req.query?['branchSlug'], 'q1');
      expect(req.query?['status'], 'in_progress');
      expect(req.query?['assignedTo'], 'emp-101');
    });

    test('propagates ApiException when getTasks fails', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('SERVER_ERROR', 'Lỗi máy chủ', 500);
      };

      expect(
        () => repository.getTasks(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SERVER_ERROR')),
      );
    });
  });

  group('TaskRepository mutations', () {
    test('createTask sends POST to /api/tasks with full payload', () async {
      mockApi.postJsonResponse = {'success': true};

      await repository.createTask(
        title: 'Lau sàn',
        description: 'Lau sàn sảnh chính',
        branchSlug: 'q1',
        status: 'pending',
        priority: 'normal',
        dueDate: '16/11/2026 12:00',
        assigneeId: 'emp-101',
        requirePhoto: true,
      );

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/tasks');
      expect(req.payload?['title'], 'Lau sàn');
      expect(req.payload?['branchSlug'], 'q1');
      expect(req.payload?['assignedTo'], 'emp-101');
      expect(req.payload?['requirePhoto'], true);
    });

    test('updateTaskStatus sends PUT to /api/tasks/:id with photo info', () async {
      mockApi.putJsonResponse = {'success': true};

      await repository.updateTaskStatus(
        'task-1',
        'completed',
        proofUrl: 'http://cdn/photo.jpg',
        photoSubmittedBy: 'emp-101',
      );

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'PUT');
      expect(req.path, '/api/tasks/task-1');
      expect(req.payload?['status'], 'completed');
      expect(req.payload?['proofPhotoUrl'], 'http://cdn/photo.jpg');
      expect(req.payload?['photoSubmittedBy'], 'emp-101');
      expect(req.payload?.containsKey('completedAt'), true);
    });

    test('updateTask & deleteTask', () async {
      mockApi.putJsonResponse = {'success': true};
      await repository.updateTask('task-1', {'title': 'Tiêu đề mới'});
      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/tasks/task-1');

      await repository.deleteTask('task-1');
      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/tasks/task-1');
    });
  });
}
