import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/services/upload_service.dart';
import '../../core/state/branch_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/models/user.dart';
import '../profile/employee_repository.dart';
import 'task_service.dart';
import 'task_repository.dart';

class TaskListScreen extends StatefulWidget {
  final UserModel currentUser;
  final String? initialFilter; // 'all', 'pending', 'overdue', 'completed'

  const TaskListScreen({
    super.key,
    this.currentUser = const UserModel(
      name: 'Nguyễn Thu Hà',
      email: 'nhanvien@company.com',
      role: 'staff',
      roleTitle: 'Nhân viên',
    ),
    this.initialFilter,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> with SingleTickerProviderStateMixin {
  final TaskRepository _taskRepo = TaskRepository();
  late TabController _tabController;
  List<TaskModel> _tasks = [];
  List<Map<String, dynamic>> _employeeList = [];

  final List<String> _tabs = [
    'Tất cả',
    'Cần làm',
    'Quá giờ',
    'Đã xong',
  ];

  @override
  void initState() {
    super.initState();
    // Chỉ dùng API thật — khởi [] rỗng, _loadTasks gán kết quả API vô điều kiện.
    _tasks = [];
    _tabController = TabController(length: _tabs.length, vsync: this);

    if (widget.initialFilter != null) {
      final index = ['all', 'pending', 'overdue', 'completed']
          .indexOf(widget.initialFilter!);
      if (index != -1) {
        _tabController.index = index;
      }
    }

    _loadEmployees();
    _loadTasks();
  }

  Future<void> _loadEmployees() async {
    try {
      final emps = await EmployeeRepository().getEmployees();
      if (mounted) {
        setState(() => _employeeList = emps);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _employeeList = []);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final remoteTasks = await _taskRepo.getTasks();
      if (mounted) {
        setState(() {
          _tasks = remoteTasks;
        });
      }
    } catch (_) {
      // Không dùng mock — lỗi thì hiện empty state.
      if (mounted) {
        setState(() {
          _tasks = [];
        });
      }
    }
  }

  List<TaskModel> _filterTasks(int tabIndex) {
    switch (tabIndex) {
      case 1: // Cần làm
        return _tasks.where((t) => t.computedStatus == TaskStatus.pending || t.computedStatus == TaskStatus.inProgress).toList();
      case 2: // Quá giờ
        return _tasks.where((t) => t.computedStatus == TaskStatus.overdue).toList();
      case 3: // Đã xong
        return _tasks.where((t) => t.computedStatus == TaskStatus.completed).toList();
      case 0: // Tất cả
      default:
        return _tasks;
    }
  }

  /// Xử lý hoàn thành công việc (chỉ có nút Hoàn thành, không có nút bắt đầu)
  void _handleCompleteTask(TaskModel task) {
    if (task.computedStatus == TaskStatus.completed) {
      // Cho phép hủy đánh dấu nếu cần
      _taskRepo.updateTaskStatus(task.id, 'pending').catchError((_) {});
      TaskService.updateTaskStatus(task.id, TaskStatus.pending);
      _loadTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển lại trạng thái cần làm: ${task.title}'),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
      return;
    }

    // Nếu quản trị viên yêu cầu chụp ảnh kết quả -> Mở giao diện chụp ảnh bắt buộc
    if (task.requirePhoto) {
      _showPhotoProofSheet(task);
    } else {
      // Không yêu cầu chụp ảnh -> Hoàn thành trực tiếp
      _taskRepo.updateTaskStatus(task.id, 'completed').catchError((_) {});
      TaskService.completeTask(task.id);
      _loadTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Đã hoàn thành: ${task.title}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Màn hình chụp ảnh minh chứng bắt buộc khi quản trị viên yêu cầu
  void _showPhotoProofSheet(TaskModel task) {
    String? tempPhotoUrl;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yêu cầu chụp ảnh minh chứng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Quản trị viên bắt buộc chụp ảnh kết quả',
                          style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chụp ảnh minh chứng tải lên Cloudinary
              if (tempPhotoUrl == null)
                InkWell(
                  onTap: isUploading
                      ? null
                      : () async {
                          final source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (modalCtx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Chọn nguồn ảnh minh chứng',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 12),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                                      title: const Text('Chụp ảnh từ máy ảnh (Camera)'),
                                      onTap: () => Navigator.pop(modalCtx, ImageSource.camera),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                      title: const Text('Chọn ảnh từ thư viện (Gallery)'),
                                      onTap: () => Navigator.pop(modalCtx, ImageSource.gallery),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (source == null) return;
                          setSheetState(() => isUploading = true);
                          try {
                            final url = await UploadService().pickAndUploadImage(source: source, folder: 'hrm/tasks');
                            if (url != null) {
                              setSheetState(() {
                                tempPhotoUrl = url;
                                isUploading = false;
                              });
                            } else {
                              setSheetState(() => isUploading = false);
                            }
                          } catch (e) {
                            setSheetState(() => isUploading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi tải ảnh lên Cloudinary: $e')),
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5), style: BorderStyle.solid, width: 1.5),
                    ),
                    child: Center(
                      child: isUploading
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.primary),
                                SizedBox(height: 12),
                                Text(
                                  'Đang tải ảnh lên Cloudinary...',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.photo_camera_rounded, color: Color(0xFFDC2626), size: 32),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Bấm vào đây để chụp ảnh minh chứng',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '(Bắt buộc phải có ảnh để hoàn thành nhiệm vụ)',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            tempPhotoUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Đã chụp ảnh kết quả',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                              onPressed: () {
                                setSheetState(() => tempPhotoUrl = null);
                              },
                              tooltip: 'Chụp lại',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setSheetState(() => tempPhotoUrl = null),
                      icon: const Icon(Icons.photo_camera_outlined, size: 16, color: AppColors.primary),
                      label: const Text('Chụp lại ảnh khác', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Nút xác nhận hoàn thành
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tempPhotoUrl != null ? AppColors.success : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: tempPhotoUrl == null
                    ? null
                    : () async {
                        Navigator.pop(sheetCtx);
                        try {
                          await TaskRepository().updateTaskStatus(
                            task.id,
                            'completed',
                            proofUrl: tempPhotoUrl,
                          );
                          _loadTasks();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✓ Đã xác nhận ảnh và hoàn thành: ${task.title}'),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Hoàn thành thất bại: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  tempPhotoUrl != null
                      ? 'Xác nhận & Hoàn thành nhiệm vụ'
                      : 'Vui lòng chụp ảnh minh chứng trước',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetail(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: task.sourceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(task.sourceIcon, size: 14, color: task.sourceColor),
                      const SizedBox(width: 4),
                      Text(
                        task.shortSourceLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: task.sourceColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: task.priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.priorityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: task.priorityColor,
                    ),
                  ),
                ),
                if (task.requirePhoto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 13, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'Cần ảnh',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: task.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: task.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildDetailRow(Icons.person_outline_rounded, 'Giao bởi', task.assignedByName),
            if (task.shiftName != null)
              _buildDetailRow(Icons.calendar_today_outlined, 'Ca làm việc', task.shiftName!),
            _buildDetailRow(
              Icons.access_time_rounded,
              'Hạn hoàn thành',
              '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')} ngày ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
              highlight: task.isOverdue,
            ),
            _buildDetailRow(
              Icons.photo_camera_outlined,
              'Yêu cầu ảnh chụp',
              task.requirePhoto ? 'Bắt buộc chụp ảnh kết quả' : 'Không bắt buộc',
              valueColor: task.requirePhoto ? const Color(0xFFDC2626) : Colors.grey.shade700,
            ),
            if (task.completedAt != null)
              _buildDetailRow(
                Icons.check_circle_outline_rounded,
                'Đã hoàn thành lúc',
                '${task.completedAt!.hour.toString().padLeft(2, '0')}:${task.completedAt!.minute.toString().padLeft(2, '0')} ngày ${task.completedAt!.day}/${task.completedAt!.month}',
                valueColor: AppColors.success,
              ),

            // Nếu đã có ảnh minh chứng -> hiển thị ảnh
            if (task.proofPhotoUrl != null) ...[
              const SizedBox(height: 14),
              const Text(
                'Ảnh minh chứng kết quả đã nộp:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  task.proofPhotoUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    alignment: Alignment.center,
                    child: const Text('Ảnh minh chứng lưu trữ nội bộ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Chỉ có nút Hoàn thành (KHÔNG CÓ NÚT BẮT ĐẦU)
            if (task.computedStatus != TaskStatus.completed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleCompleteTask(task);
                  },
                  icon: Icon(task.requirePhoto ? Icons.photo_camera_rounded : Icons.check_rounded, color: Colors.white),
                  label: Text(
                    task.requirePhoto ? 'Chụp ảnh & Hoàn thành' : 'Đã hoàn thành',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      SizedBox(width: 8),
                      Text('Công việc đã được hoàn tất thành công!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool highlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? (highlight ? const Color(0xFFDC2626) : AppColors.textPrimary),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog giao việc mới dành cho Quản lý & Quản trị viên
  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskSourceType selectedSource = TaskSourceType.manager;
    TaskPriority selectedPriority = TaskPriority.normal;
    String selectedShift = 'Ca Sáng (07:00 - 14:00)';
    final String? initialStaff = _employeeList.isNotEmpty
        ? _employeeList.first['name']?.toString()
        : null;
    String? assignedPerson = initialStaff;
    bool requirePhoto = false; // Quản trị viên được phép yêu cầu chụp ảnh hoặc không

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Giao công việc mới',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề công việc *',
                    hintText: 'Ví dụ: Kiểm tra quầy bar, đối chiếu hoá đơn...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.assignment_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mô tả chi tiết / Chỉ đạo',
                    hintText: 'Nội dung hướng dẫn thực hiện cho nhân sự...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<TaskSourceType>(
                  initialValue: selectedSource,
                  decoration: InputDecoration(
                    labelText: 'Hình thức giao việc',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: TaskSourceType.manager, child: Text('📌 Quản lý giao riêng')),
                    DropdownMenuItem(value: TaskSourceType.shift, child: Text('🔄 Giao cố định theo ca')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSource = val);
                  },
                ),
                const SizedBox(height: 12),
                if (selectedSource == TaskSourceType.shift) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedShift,
                    decoration: InputDecoration(
                      labelText: 'Ca làm việc áp dụng',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Ca Sáng (07:00 - 14:00)', child: Text('Ca Sáng (07:00 - 14:00)')),
                      DropdownMenuItem(value: 'Ca Chiều (14:00 - 22:00)', child: Text('Ca Chiều (14:00 - 22:00)')),
                      DropdownMenuItem(value: 'Ca Tối (18:00 - 23:00)', child: Text('Ca Tối (18:00 - 23:00)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedShift = val);
                    },
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: assignedPerson,
                    decoration: InputDecoration(
                      labelText: 'Nhân sự thực hiện (Giao riêng)',
                      hintText: _employeeList.isEmpty ? 'Chưa có dữ liệu nhân sự' : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    // Chỉ load từ getEmployees() — rỗng thì dropdown rỗng.
                    items: _employeeList.map((e) {
                            final name = e['name']?.toString() ?? 'Nhân viên';
                            final role = e['role']?.toString() ?? 'Nhân viên';
                            return DropdownMenuItem(
                              value: name,
                              child: Text('$name ($role)'),
                            );
                          }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => assignedPerson = val);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: selectedPriority,
                  decoration: InputDecoration(
                    labelText: 'Mức độ ưu tiên',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: TaskPriority.normal, child: Text('🟢 Bình thường')),
                    DropdownMenuItem(value: TaskPriority.high, child: Text('🟠 Quan trọng')),
                    DropdownMenuItem(value: TaskPriority.urgent, child: Text('🔴 Khẩn cấp')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedPriority = val);
                  },
                ),
                const SizedBox(height: 14),

                // Tuỳ chọn yêu cầu chụp ảnh kết quả của Quản trị viên
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: requirePhoto ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: requirePhoto ? const Color(0xFFFCA5A5) : Colors.grey.shade200,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Yêu cầu chụp ảnh minh chứng',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Bắt buộc nhân viên chụp ảnh kết quả mới được bấm hoàn thành',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    secondary: Icon(
                      Icons.photo_camera_outlined,
                      color: requirePhoto ? const Color(0xFFDC2626) : Colors.grey.shade500,
                    ),
                    value: requirePhoto,
                    activeThumbColor: const Color(0xFFDC2626),
                    onChanged: (bool val) {
                      setDialogState(() => requirePhoto = val);
                    },
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập tiêu đề công việc')),
                      );
                      return;
                    }

                    final bool isShift = selectedSource == TaskSourceType.shift;
                    final branch = BranchScope.selectedBranch(context);
                    final branchSlug = branch?.slug ?? 'hn-1';

                    String? assigneeId;
                    if (!isShift && assignedPerson != null) {
                      final match = _employeeList.firstWhere(
                        (e) => e['name']?.toString() == assignedPerson,
                        orElse: () => <String, dynamic>{},
                      );
                      assigneeId = match['id']?.toString();
                    }

                    final priStr = selectedPriority == TaskPriority.urgent
                        ? 'urgent'
                        : (selectedPriority == TaskPriority.high ? 'high' : 'normal');

                    try {
                      await _taskRepo.createTask(
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? 'Thực hiện theo chỉ đạo của quản lý.'
                            : descCtrl.text.trim(),
                        branchSlug: branchSlug,
                        priority: priStr,
                        assigneeId: assigneeId,
                      );
                      if (sheetCtx.mounted) {
                        Navigator.pop(sheetCtx);
                      }
                      if (!mounted) return;
                      _loadTasks();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Đã giao việc thành công cho ${assignedPerson ?? 'nhân sự đã chọn'}!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Giao việc thất bại: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Phát hành & Giao việc ngay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = TaskService.getTaskStats(tasks: _tasks);
    final bool canManage = widget.currentUser.canManage;
    final bool isAdmin = widget.currentUser.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Công việc cần làm',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (isAdmin) const BranchSelector(includeAll: true),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: 'Tất cả (${stats['total'] ?? 0})'),
            Tab(text: 'Cần làm (${(stats['pending'] ?? 0) + (stats['inProgress'] ?? 0)})'),
            Tab(text: 'Quá giờ (${stats['overdue'] ?? 0})'),
            Tab(text: 'Đã xong (${stats['completed'] ?? 0})'),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _showCreateTaskDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
              label: const Text('Giao việc', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIndex) {
          final filtered = _filterTasks(tabIndex);

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadTasks,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.playlist_add_check_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Không có công việc nào',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Mọi nhiệm vụ trong mục này đã được hoàn tất',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final task = filtered[index];
                return _buildTaskCard(task);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isDone = task.computedStatus == TaskStatus.completed;
    final bool isOverdue = task.computedStatus == TaskStatus.overdue;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? const Color(0xFFFCA5A5) : Colors.grey.shade200,
          width: isOverdue ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showTaskDetail(task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng tag tinh gọn - chỉ hiện thông tin quan trọng, Wrap tự động chống tràn 100%
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Nguồn việc ngắn gọn: 'Theo ca' hoặc 'Giao riêng'
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: task.sourceColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(task.sourceIcon, size: 12, color: task.sourceColor),
                              const SizedBox(width: 3.5),
                              Text(
                                task.shortSourceLabel,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: task.sourceColor),
                              ),
                            ],
                          ),
                        ),

                        // Mức độ ưu tiên: CHỈ HIỆN KHI KHẨN CẤP HOẶC QUAN TRỌNG (Bình thường ẩn đi để thoáng)
                        if (task.priority != TaskPriority.normal)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: task.priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (task.priority == TaskPriority.urgent) ...[
                                  const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 2),
                                ],
                                Text(
                                  task.priorityLabel,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: task.priorityColor),
                                ),
                              ],
                            ),
                          ),

                        // Yêu cầu ảnh chụp nhỏ gọn
                        if (task.requirePhoto)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 12, color: Color(0xFFDC2626)),
                                SizedBox(width: 3),
                                Text(
                                  'Cần ảnh',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Cột trạng thái bên phải: Chỉ hiện khi 'Quá giờ' hoặc 'Đã xong'
                  if (isOverdue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                          SizedBox(width: 3),
                          Text(
                            'Quá giờ',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isDone) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Đã xong',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Tiêu đề & Checkbox Hoàn thành duy nhất
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _handleCompleteTask(task),
                    child: Container(
                      margin: const EdgeInsets.only(top: 2, right: 10),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.success : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isDone
                              ? AppColors.success
                              : (task.requirePhoto ? const Color(0xFFDC2626) : Colors.grey.shade400),
                          width: 1.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : (task.requirePhoto
                              ? const Icon(Icons.photo_camera_rounded, size: 14, color: Color(0xFFDC2626))
                              : null),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.grey.shade500 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Thông tin giao & hạn chót
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.assignedByName,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.access_time_rounded, size: 14, color: isOverdue ? const Color(0xFFDC2626) : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? const Color(0xFFDC2626) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
