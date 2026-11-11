import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/upload_service.dart';
import '../../core/state/branch_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../../core/models/branch.dart';
import '../../core/models/user.dart';
import '../../core/utils/date_format.dart';
import '../profile/employee_repository.dart';
import '../schedule/shift_repository.dart';
import 'task_service.dart';
import 'task_repository.dart';

class TaskListScreen extends StatefulWidget {
  final UserModel currentUser;
  final String? initialFilter; // 'all', 'pending', 'overdue', 'completed'

  const TaskListScreen({
    super.key,
    required this.currentUser,
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
  List<Branch> _branchList = [];
  List<Map<String, dynamic>> _shiftTemplates = [];
  String? _tasksError;
  bool _isLoading = true;

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

    // Chờ animation trượt màn hình (~300ms) kết thúc rồi mới tải dữ liệu,
    // tránh setState liên tục giữa transition gây giật khung hình.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _loadTasks();
    });
  }

  Future<void> _loadBranchesAndTemplates() async {
    try {
      final branches = await EmployeeRepository().getBranches();
      if (mounted) setState(() => _branchList = branches);
    } catch (_) {}

    try {
      final templates = await ShiftRepository().getTemplates();
      if (mounted) setState(() => _shiftTemplates = templates);
    } catch (_) {}
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
          _tasksError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Giữ danh sách cũ, báo lỗi — không được giả vờ "đã xong hết việc".
      if (mounted) {
        setState(() {
          _tasksError = e is ApiException ? e.message : 'Không tải được danh sách công việc';
          _isLoading = false;
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
  Future<void> _handleCompleteTask(TaskModel task) async {
    if (task.computedStatus == TaskStatus.completed) {
      // Cho phép hủy đánh dấu nếu cần
      try {
        await _taskRepo.updateTaskStatus(task.id, 'pending');
        if (!mounted) return;
        _loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển lại trạng thái cần làm: ${task.title}'),
            backgroundColor: AppColors.infoLight,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ ${e is ApiException ? e.message : e}'),
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    // Nếu quản trị viên yêu cầu chụp ảnh kết quả -> Mở giao diện chụp ảnh bắt buộc
    if (task.requirePhoto) {
      _showPhotoProofSheet(task);
    } else {
      // Không yêu cầu chụp ảnh -> Hoàn thành trực tiếp
      try {
        await _taskRepo.updateTaskStatus(task.id, 'completed');
        if (!mounted) return;
        _loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Đã hoàn thành: ${task.title}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text('❌ ${e is ApiException ? e.message : e}'),
          duration: const Duration(seconds: 3),
        ));
      }
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
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: AppColors.error, size: 24),
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
                          style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
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
                      task.description.trim().isEmpty
                          ? 'Không có hướng dẫn'
                          : task.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                            ? Colors.grey.shade400
                            : AppColors.textSecondary,
                        fontStyle: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chụp ảnh minh chứng tải lên máy chủ nội bộ
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
                                SnackBar(content: Text('Lỗi tải ảnh lên máy chủ: $e')),
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.errorBorder, style: BorderStyle.solid, width: 1.5),
                    ),
                    child: Center(
                      child: isUploading
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.primary),
                                SizedBox(height: 12),
                                Text(
                                  'Đang tải ảnh lên máy chủ...',
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
                                  child: const Icon(Icons.photo_camera_rounded, color: AppColors.error, size: 32),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Bấm vào đây để chụp ảnh minh chứng',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.errorDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '(Bắt buộc phải có ảnh để hoàn thành nhiệm vụ)',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.error),
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
                            headers: ApiClient.imageHeadersFor(tempPhotoUrl!),
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
                        try {
                          await TaskRepository().updateTaskStatus(
                            task.id,
                            'completed',
                            proofUrl: tempPhotoUrl,
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (!mounted) return;
                          _loadTasks();
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: AppColors.error,
                            content: Text('❌ ${e is ApiException ? e.message : e}'),
                            duration: const Duration(seconds: 3),
                          ));
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
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 13, color: AppColors.error),
                        SizedBox(width: 4),
                        Text(
                          'Cần ảnh',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
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
              task.description.trim().isEmpty
                  ? 'Không có hướng dẫn'
                  : task.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                    ? Colors.grey.shade400
                    : AppColors.textSecondary,
                fontStyle: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                    ? FontStyle.italic
                    : FontStyle.normal,
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
              task.dueDate == null ? 'Chưa đặt hạn' : vnDateTime(task.dueDate!),
              highlight: task.isOverdue,
            ),
            _buildDetailRow(
              Icons.photo_camera_outlined,
              'Yêu cầu ảnh chụp',
              task.requirePhoto ? 'Bắt buộc chụp ảnh kết quả' : 'Không bắt buộc',
              valueColor: task.requirePhoto ? AppColors.error : Colors.grey.shade700,
            ),
            if (task.completedAt != null)
              _buildDetailRow(
                Icons.check_circle_outline_rounded,
                'Đã hoàn thành lúc',
                vnDateTime(task.completedAt!),
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
                  headers: ApiClient.imageHeadersFor(task.proofPhotoUrl!),
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
                color: valueColor ?? (highlight ? AppColors.error : AppColors.textPrimary),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog giao việc mới dành cho Quản lý & Quản trị viên
  Future<void> _showCreateTaskDialog() async {
    // Chỉ tải nhân sự/chi nhánh/ca mẫu khi mở dialog, không tải lúc vào màn
    // hình để tránh rebuild giữa animation điều hướng.
    await Future.wait([_loadEmployees(), _loadBranchesAndTemplates()]);
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskSourceType selectedSource = TaskSourceType.manager;
    TaskPriority selectedPriority = TaskPriority.normal;

    // Danh sách ca mẫu
    final shiftOptions = _shiftTemplates.isNotEmpty
        ? _shiftTemplates.map((t) {
            final name = t['name']?.toString() ?? 'Ca';
            final start = t['startTime']?.toString() ?? '07:00';
            final end = t['endTime']?.toString() ?? '14:00';
            return '$name ($start - $end)';
          }).toList()
        : [
            'Ca Sáng (07:00 - 14:00)',
            'Ca Chiều (14:00 - 22:00)',
            'Ca Tối (18:00 - 23:00)',
          ];
    String selectedShift = shiftOptions.first;

    final String? initialStaff = _employeeList.isNotEmpty
        ? _employeeList.first['name']?.toString()
        : null;
    String? assignedPerson = initialStaff;

    // Chi nhánh
    final currentScopeBranch = BranchScope.selectedBranch(context);
    String targetBranch = currentScopeBranch?.slug ?? (_branchList.isNotEmpty ? _branchList.first.slug : '');

    // Deadline mặc định: 4 tiếng sau
    DateTime selectedDeadline = DateTime.now().add(const Duration(hours: 4));

    bool requirePhoto = false;

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

                // Tiêu đề
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề công việc *',
                    hintText: 'Ví dụ: Kiểm tra quầy bar, đối soát phiếu thu...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.assignment_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 12),

                // Hình thức giao việc (manager vs shift)
                DropdownButtonFormField<TaskSourceType>(
                  initialValue: selectedSource,
                  decoration: InputDecoration(
                    labelText: 'Phân loại nguồn việc',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: TaskSourceType.manager, child: Text('📌 Quản lý giao riêng')),
                    DropdownMenuItem(value: TaskSourceType.shift, child: Text('🔄 Cố định theo ca làm việc')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSource = val);
                  },
                ),
                const SizedBox(height: 12),

                if (selectedSource == TaskSourceType.shift) ...[
                  // Ca làm việc áp dụng
                  DropdownButtonFormField<String>(
                    initialValue: selectedShift,
                    decoration: InputDecoration(
                      labelText: 'Ca làm việc áp dụng (từ DB)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: shiftOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedShift = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Chi nhánh áp dụng
                  if (_branchList.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _branchList.any((b) => b.slug.toLowerCase() == targetBranch.toLowerCase())
                          ? _branchList.firstWhere((b) => b.slug.toLowerCase() == targetBranch.toLowerCase()).slug
                          : _branchList.first.slug,
                      decoration: InputDecoration(
                        labelText: 'Chi nhánh áp dụng',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _branchList.map((b) => DropdownMenuItem(value: b.slug, child: Text('${b.name} (${b.slug.toUpperCase()})'))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => targetBranch = val);
                      },
                    ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Nhân sự thực hiện
                  DropdownButtonFormField<String>(
                    initialValue: assignedPerson,
                    decoration: InputDecoration(
                      labelText: 'Người thực hiện (Nhân sự) *',
                      hintText: _employeeList.isEmpty ? 'Chưa có dữ liệu nhân sự' : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _employeeList.map((e) {
                      final name = e['name']?.toString() ?? 'Nhân viên';
                      final role = e['role']?.toString() ?? 'Nhân viên';
                      final branchSlug =
                          e['branchSlug']?.toString() ?? e['branch']?.toString() ?? '';
                      // Map slug→tên chi nhánh từ _branchList đã nạp; không map được giữ nguyên.
                      String branchLabel = branchSlug;
                      for (final b in _branchList) {
                        if (b.slug.toLowerCase() == branchSlug.toLowerCase() ||
                            b.code.toLowerCase() == branchSlug.toLowerCase()) {
                          branchLabel = b.name;
                          break;
                        }
                      }
                      return DropdownMenuItem(
                        value: name,
                        child: Text('$name ($role${branchSlug.isNotEmpty ? ' - $branchLabel' : ''})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => assignedPerson = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Mức độ ưu tiên
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
                const SizedBox(height: 12),

                // Hạn chót hoàn thành (Deadline)
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: sheetCtx,
                      initialDate: selectedDeadline,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      if (!sheetCtx.mounted) return;
                      final pickedTime = await showTimePicker(
                        context: sheetCtx,
                        initialTime: TimeOfDay.fromDateTime(selectedDeadline),
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          selectedDeadline = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hạn chót hoàn thành (Deadline) *',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              vnDateTime(selectedDeadline),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Yêu cầu chụp ảnh minh chứng
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: requirePhoto ? AppColors.errorBg : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: requirePhoto ? AppColors.errorBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Yêu cầu chụp ảnh minh chứng kết quả',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Bắt buộc nhân viên chụp ảnh thực tế mới được hoàn thành',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    secondary: Icon(
                      Icons.photo_camera_outlined,
                      color: requirePhoto ? AppColors.error : Colors.grey.shade500,
                    ),
                    value: requirePhoto,
                    activeThumbColor: AppColors.error,
                    onChanged: (bool val) {
                      setDialogState(() => requirePhoto = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Mô tả chi tiết
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mô tả chi tiết / Hướng dẫn thực hiện',
                    hintText: 'Nội dung chi tiết, các tiêu chuẩn hoặc lưu ý cần kiểm tra...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Nút tạo
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

                    Map<String, dynamic>? selectedEmpObj;
                    if (!isShift && assignedPerson != null) {
                      selectedEmpObj = _employeeList.firstWhere(
                        (e) => e['name']?.toString() == assignedPerson,
                        orElse: () => <String, dynamic>{},
                      );
                    }

                    final empName = isShift
                        ? 'Tất cả nhân sự trực ${selectedShift.split('(')[0].trim()}'
                        : (assignedPerson ?? 'Nhân viên');
                    final empEmail = isShift ? 'shift_all' : (selectedEmpObj?['email']?.toString() ?? '');
                    final assigneeId = selectedEmpObj?['id']?.toString() ?? (isShift ? null : assignedPerson);

                    final effectiveBranch = isShift
                        ? targetBranch
                        : (selectedEmpObj?['branchSlug']?.toString() ?? selectedEmpObj?['branch']?.toString() ?? targetBranch);

                    final priStr = selectedPriority == TaskPriority.urgent
                        ? 'urgent'
                        : (selectedPriority == TaskPriority.high ? 'high' : 'normal');

                    final dueDateStr = vnDateTime(selectedDeadline);

                    final currentUserName = widget.currentUser.name.isNotEmpty
                        ? '${widget.currentUser.name} (${widget.currentUser.roleTitle.isNotEmpty ? widget.currentUser.roleTitle : 'Quản lý'})'
                        : 'Ban Quản lý';

                    try {
                      await _taskRepo.createTask(
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        branchSlug: effectiveBranch,
                        priority: priStr,
                        dueDate: dueDateStr,
                        assigneeId: assigneeId,
                        sourceType: isShift ? 'shift' : 'manager',
                        assignedByName: isShift ? 'Quy trình ${selectedShift.split('(')[0].trim()}' : currentUserName,
                        shiftName: isShift ? selectedShift : null,
                        assignedToEmail: empEmail,
                        assignedToName: empName,
                        requirePhoto: requirePhoto,
                      );
                      if (sheetCtx.mounted) {
                        Navigator.pop(sheetCtx);
                      }
                      if (!mounted) return;
                      _loadTasks();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Đã giao việc thành công: ${titleCtrl.text.trim()}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('❌ ${e is ApiException ? e.message : e}'),
                        duration: const Duration(seconds: 3),
                      ));
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
          'Giao việc & Nhiệm vụ',
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

          // Đang tải lần đầu: hiện spinner thay vì chớp empty-state rồi nhảy
          // sang danh sách gây giật giao diện.
          if (_isLoading && _tasks.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (_tasksError != null && _tasks.isEmpty) {
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
                        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 14),
                        const Text(
                          'Không tải được danh sách công việc',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            '${_tasksError!}\nKéo xuống để thử lại.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

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
          color: isOverdue ? AppColors.errorBorder : Colors.grey.shade200,
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
                                  const Icon(Icons.local_fire_department_rounded, size: 13, color: AppColors.error),
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
                              color: AppColors.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 12, color: AppColors.error),
                                SizedBox(width: 3),
                                Text(
                                  'Cần ảnh',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
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
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                          SizedBox(width: 3),
                          Text(
                            'Quá giờ',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.error),
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
                              : (task.requirePhoto ? AppColors.error : Colors.grey.shade400),
                          width: 1.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : (task.requirePhoto
                              ? const Icon(Icons.photo_camera_rounded, size: 14, color: AppColors.error)
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
                          task.description.trim().isEmpty
                              ? 'Không có hướng dẫn'
                              : task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontStyle: task.description.trim().isEmpty || task.description == 'Không có hướng dẫn'
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
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
                  Icon(Icons.access_time_rounded, size: 14, color: isOverdue ? AppColors.error : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    task.dueDate == null
                        ? '—'
                        : '${task.dueDate!.hour.toString().padLeft(2, '0')}:${task.dueDate!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? AppColors.error : Colors.grey.shade700,
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
