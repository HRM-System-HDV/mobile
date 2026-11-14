import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/tasks/task_repository.dart';
import 'package:mobile/src/features/tasks/task_service.dart';

import 'mock_api_client.dart';

const _taskUuid = '7f0f0e2a-3b7c-4c1d-9e2a-1c2b3d4e5f60';
const _doneUuid = '8e1e1f3b-4c8d-5d2e-af3b-2d3e4f5a6170';
const _branchUuid = '1b2b3b4b-5c6d-7e8f-9a0b-1c2d3e4f5060';
const _templateUuid = '2c3d4e5f-6a7b-8c9d-0e1f-2a3b4c5d6070';
const _employeeUuid = '3d4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7080';

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
          'id': _taskUuid,
          'title': 'Dọn quầy bar',
          'description': 'Lau sạch các máy pha chế',
          'branchId': _branchUuid,
          'templateId': _templateUuid,
          'workDate': '2026-11-15',
          'status': 'in_progress',
          'priority': 'urgent',
          'dueDate': '2026-11-15',
          'assignedTo': _employeeUuid,
          'assignedToName': 'Nguyễn Văn A',
          'assignedByName': 'Quản lý B',
          'shiftName': 'Ca Chiều',
          'requirePhoto': true,
          'proofPhotoUrl': 'http://image.url/proof.jpg',
        },
        {
          'id': _doneUuid,
          'title': 'Kiểm kê kho',
          'status': 'done',
          'priority': 'high',
          'completedAt': '2026-11-15T13:00:00.000Z',
        }
      ];

      final tasks = await repository.getTasks(
        status: 'in_progress',
        assigneeId: _employeeUuid,
      );

      expect(tasks.length, 2);

      final t1 = tasks[0];
      expect(t1.id, _taskUuid);
      expect(t1.title, 'Dọn quầy bar');
      expect(t1.status, TaskStatus.inProgress);
      expect(t1.priority, TaskPriority.urgent);
      expect(t1.sourceType, TaskSourceType.shift);
      expect(t1.shiftName, 'Ca Chiều');
      expect(t1.branch, _branchUuid);
      expect(t1.requirePhoto, true);
      expect(t1.proofPhotoUrl, 'http://image.url/proof.jpg');

      final t2 = tasks[1];
      expect(t2.id, _doneUuid);
      expect(t2.status, TaskStatus.completed);
      expect(t2.priority, TaskPriority.high);

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.path, '/api/tasks');
      expect(req.query?.containsKey('branchSlug'), isFalse);
      expect(req.query?['status'], 'in_progress');
      expect(req.query?['assignedTo'], _employeeUuid);
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
    test('createTask sends exactly TASK_FIELDS for a personal task', () async {
      mockApi.postJsonResponse = {'id': _taskUuid};

      await repository.createTask(
        title: 'Lau sàn',
        description: 'Lau sàn sảnh chính',
        assigneeId: _employeeUuid,
        status: 'pending',
        priority: 'normal',
        dueDate: '2026-11-16',
        requirePhoto: true,
      );

      final req = mockApi.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/tasks');
      expect(req.payload?['title'], 'Lau sàn');
      expect(req.payload?['assignedTo'], _employeeUuid);
      expect(req.payload?['requirePhoto'], true);
      expect(req.payload?.keys.toSet(), {
        'title',
        'description',
        'assignedTo',
        'status',
        'priority',
        'dueDate',
        'requirePhoto',
      });
    });

    test('createTask sends branchId, templateId and workDate for shared work', () async {
      mockApi.postJsonResponse = {'id': _taskUuid};

      await repository.createTask(
        title: 'Tổng vệ sinh',
        description: 'Dọn toàn chi nhánh',
        branchId: _branchUuid,
        templateId: _templateUuid,
        workDate: '2026-11-16',
        priority: 'high',
      );

      final req = mockApi.requests.single;
      expect(req.payload?['assignedTo'], isNull);
      expect(req.payload?['branchId'], _branchUuid);
      expect(req.payload?['templateId'], _templateUuid);
      expect(req.payload?['workDate'], '2026-11-16');
      expect(req.payload?.keys.toSet(), {
        'title',
        'description',
        'assignedTo',
        'branchId',
        'templateId',
        'workDate',
        'status',
        'priority',
        'requirePhoto',
      });
    });

    test('updateTaskStatus maps completed to done and omits self-set fields', () async {
      mockApi.putJsonResponse = {'ok': true};

      await repository.updateTaskStatus(
        _taskUuid,
        'completed',
        proofUrl: 'http://cdn/photo.jpg',
      );

      final req = mockApi.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/tasks/$_taskUuid');
      expect(req.payload?['status'], 'done');
      expect(req.payload?['proofPhotoUrl'], 'http://cdn/photo.jpg');
      expect(req.payload?.keys.toSet(), {'status', 'proofPhotoUrl'});
    });

    test('updateTaskStatus maps inProgress to in_progress', () async {
      mockApi.putJsonResponse = {'ok': true};

      await repository.updateTaskStatus(_taskUuid, 'inProgress');

      expect(mockApi.requests.single.payload, {'status': 'in_progress'});
    });

    test('updateTask & deleteTask', () async {
      mockApi.putJsonResponse = {'ok': true};
      await repository.updateTask(_taskUuid, {'title': 'Tiêu đề mới'});
      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/tasks/$_taskUuid');

      await repository.deleteTask(_taskUuid);
      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/tasks/$_taskUuid');
    });
  });
}
