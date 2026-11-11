import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/utils/date_format.dart';
import 'notification_repository.dart';
import 'request_detail.dart';

// ─── State Quản lý số lượng thông báo chưa đọc ────────────────────────────────
class NotificationState {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static void updateCount(int count) {
    unreadCount.value = count;
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class NotificationItem {
  final String id;
  final String title;
  final String content;
  final String time;
  final FaIconData icon;
  final Color iconColor;
  bool isRead;

  // Thuộc tính yêu cầu đổi ca / nhờ làm thay (nếu có)
  final String? requestId; // id đơn từ thật (metadata.requestId), KHÔNG dùng id thông báo
  final String? requestType; // 'cover' hoặc 'swap'
  final String? senderName;
  final String? senderRole;
  final String? senderPhone;
  final String? shiftName;
  final String? shiftTime;
  final String? shiftHours;
  final String? shiftDate;
  final String? branch;
  final String? shiftRole;
  final String? swapShiftName;
  final String? swapShiftTime;
  final String? swapShiftHours;
  final String? swapShiftDate;
  final String? swapShiftBranch;
  final String? swapShiftRole;
  final String? reason;
  ShiftRequestStatus requestStatus;

  /// Chỉ thông báo có cả id đơn thật lẫn loại yêu cầu mới mở được màn phản hồi ca.
  bool get isShiftRequest =>
      (requestId ?? '').isNotEmpty && (requestType ?? '').isNotEmpty;

  NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
    this.requestId,
    this.requestType,
    this.senderName,
    this.senderRole,
    this.senderPhone,
    this.shiftName,
    this.shiftTime,
    this.shiftHours,
    this.shiftDate,
    this.branch,
    this.shiftRole,
    this.swapShiftName,
    this.swapShiftTime,
    this.swapShiftHours,
    this.swapShiftDate,
    this.swapShiftBranch,
    this.swapShiftRole,
    this.reason,
    this.requestStatus = ShiftRequestStatus.pending,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository();
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  late List<NotificationItem> _notifications;
  String? _loadedUserId;
  String? _loadError;
  Timer? _pollTimer;
  final Set<String> _knownIds = {};
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    // Chỉ dùng API thật; khởi rỗng để hiện empty state khi API chưa về/rỗng.
    _notifications = [];
    _syncUnreadCount();
    // Quét thông báo mới định kỳ để bắn cảnh báo local (âm thanh/rung theo cài đặt).
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = UserScope.currentUser(context)?.id ?? '';
    if (_loadedUserId != uid) {
      _loadedUserId = uid;
      _firstLoadDone = false;
      _knownIds.clear();
      NotificationSettingsCache.refresh(userId: uid.isEmpty ? null : uid);
      _fetchNotifications();
    }
  }

  /// Thông báo gửi đích danh chỉ hiện khi lọc theo đúng nhân sự đang đăng nhập.
  String? get _employeeId {
    final uid = UserScope.currentUser(context)?.id ?? '';
    return uid.isEmpty ? null : uid;
  }

  String? _rawString(Map<String, dynamic> raw, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  Future<void> _fetchNotifications() async {
    try {
      final employeeId = _employeeId;
      final list = await _repo.getNotifications(employeeId: employeeId);
      if (mounted) {
        final remoteItems = list.map((m) {
          final metaMap = m.metadata ?? const <String, dynamic>{};

          // Chỉ nhận loại yêu cầu do backend gắn tường minh. Không suy đoán từ
          // title/body: thông báo duyệt đơn cũng chứa chữ "làm thay/đổi ca" nên
          // suy đoán sẽ biến chúng thành thẻ phản hồi ca sai.
          String? requestType = m.requestType ??
              _rawString(metaMap, [
                'requestType',
                'request_type',
                'shiftRequestType',
              ]);
          if (requestType != null) {
            final v = requestType.toLowerCase();
            if (v.contains('swap')) {
              requestType = 'swap';
            } else if (v.contains('cover')) {
              requestType = 'cover';
            } else {
              requestType = null;
            }
          }

          // id đơn từ thật nằm trong metadata; thiếu nó thì không mở màn phản hồi.
          final String? requestId =
              _rawString(metaMap, ['requestId', 'request_id']);
          final String? statusRaw = _rawString(
            metaMap,
            ['requestStatus', 'request_status'],
          )?.toLowerCase();
          ShiftRequestStatus requestStatus = ShiftRequestStatus.pending;
          if (statusRaw != null) {
            if (statusRaw.contains('reject') || statusRaw.contains('từ chối')) {
              requestStatus = ShiftRequestStatus.rejected;
            } else if (statusRaw.contains('approv') || statusRaw.contains('accept') || statusRaw.contains('chấp nhận')) {
              requestStatus = ShiftRequestStatus.accepted;
            }
          }
          if ((requestId ?? '').isEmpty) requestType = null;

          final bool isReq = requestType != null;
          return NotificationItem(
            id: m.id,
            title: m.title,
            content: m.body,
            time: (m.createdAt == null || m.createdAt!.trim().isEmpty)
                ? 'Vừa xong'
                : toVnDateTime(m.createdAt),
            icon: isReq
                ? (requestType == 'swap'
                    ? FontAwesomeIcons.arrowsLeftRight
                    : FontAwesomeIcons.userPlus)
                : FontAwesomeIcons.bell,
            iconColor: isReq
                ? (requestType == 'swap' ? AppColors.primary : Colors.orange)
                : Colors.blue,
            isRead: m.isRead,
            requestId: requestId,
            requestStatus: requestStatus,
            requestType: requestType,
            senderName: m.senderName ?? _rawString(metaMap, ['senderName', 'sender', 'employeeName']),
            senderRole: m.senderRole ?? _rawString(metaMap, ['senderRole', 'role']),
            senderPhone: m.senderPhone ?? _rawString(metaMap, ['senderPhone', 'phone']),
            shiftName: m.shiftName ?? _rawString(metaMap, ['shiftName', 'shift']),
            shiftTime: m.shiftTime ?? _rawString(metaMap, ['shiftTime', 'time']),
            shiftHours: m.shiftHours ?? _rawString(metaMap, ['shiftHours', 'hours']),
            shiftDate: m.shiftDate ?? _rawString(metaMap, ['shiftDate', 'date']),
            branch: m.branchSlug ?? _rawString(metaMap, ['branch', 'branchSlug']),
            shiftRole: _rawString(metaMap, ['shiftRole']),
            swapShiftName: _rawString(metaMap, ['swapShiftName']),
            swapShiftTime: _rawString(metaMap, ['swapShiftTime']),
            swapShiftHours: _rawString(metaMap, ['swapShiftHours']),
            swapShiftDate: _rawString(metaMap, ['swapShiftDate']),
            swapShiftBranch: _rawString(metaMap, ['swapShiftBranch']),
            swapShiftRole: _rawString(metaMap, ['swapShiftRole']),
            reason: _rawString(metaMap, ['reason']) ?? m.body,
          );
        }).toList();
        setState(() {
          _notifications = remoteItems;
          _loadError = null;
        });
        _syncUnreadCount();
        _alertNewItems(remoteItems);
      }
    } catch (e) {
      // Không hiện "đã dọn sạch" khi thực chất là gọi API thất bại.
      if (mounted) setState(() => _loadError = e is ApiException ? e.message : 'Không tải được thông báo');
    }
  }

  void _syncUnreadCount() {
    final count = _notifications.where((n) => !n.isRead).length;
    NotificationState.updateCount(count);
  }

  /// Lần tải đầu chỉ ghi nhận danh sách; các lần sau bắn cảnh báo local cho
  /// thông báo chưa đọc mới xuất hiện, theo đúng cài đặt người dùng.
  void _alertNewItems(List<NotificationItem> items) {
    final fresh = items.where((n) => !n.isRead && !_knownIds.contains(n.id)).toList();
    _knownIds
      ..clear()
      ..addAll(items.map((n) => n.id));
    if (!_firstLoadDone) {
      _firstLoadDone = true;
      return;
    }
    if (fresh.isEmpty || !NotificationSettingsCache.get('tabNotificationAlert')) return;
    final sound = NotificationSettingsCache.get('soundEnabled');
    final vibrate = NotificationSettingsCache.get('vibrateEnabled');
    for (final item in fresh.take(3)) {
      LocalNotifier.instance.show(
        item.id.hashCode.abs() % 100000,
        item.title,
        item.content,
        sound: sound,
        vibrate: vibrate,
      );
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Không kết nối được máy chủ, vui lòng thử lại.';

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text('❌ $message'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    try {
      await _repo.markAllRead();
    } catch (e) {
      _showError(_errorText(e));
      return;
    }
    if (!mounted) return;
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
    _syncUnreadCount();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('✅ Đã đánh dấu tất cả thông báo là đã đọc'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _notifications.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_notifications.map((n) => n.id));
      }
    });
  }

  /// Gọi từng id, không để một lỗi chặn các id còn lại.
  Future<({Set<String> done, Object? error})> _runPerId(
    Iterable<String> ids,
    Future<void> Function(String) action,
  ) async {
    final done = <String>{};
    Object? error;
    await Future.wait(ids.map((id) async {
      try {
        await action(id);
        done.add(id);
      } catch (e) {
        error ??= e;
      }
    }));
    return (done: done, error: error);
  }

  Future<void> _markSelectedAsRead() async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final result = await _runPerId(ids, _repo.markRead);
    if (!mounted) return;
    setState(() {
      for (var item in _notifications) {
        if (result.done.contains(item.id)) {
          item.isRead = true;
        }
      }
      _isSelecting = false;
      _selectedIds.clear();
    });
    _syncUnreadCount();
    if (result.error != null) {
      _showError(
        'Chỉ đánh dấu đã đọc được ${result.done.length}/${ids.length} thông báo. ${_errorText(result.error!)}',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('✅ Đã đánh dấu đã đọc các thông báo đã chọn'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoá thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('Bạn có chắc chắn muốn xoá $count thông báo đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ids = _selectedIds.toList();
              final result = await _runPerId(ids, _repo.deleteNotification);
              if (!mounted) return;
              setState(() {
                _notifications.removeWhere((n) => result.done.contains(n.id));
                _isSelecting = false;
                _selectedIds.clear();
              });
              _syncUnreadCount();
              if (result.error != null) {
                _showError(
                  'Chỉ xoá được ${result.done.length}/${ids.length} thông báo. ${_errorText(result.error!)}',
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.error,
                  content: Text('🗑️ Đã xoá ${result.done.length} thông báo'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSingle(NotificationItem item) async {
    final index = _notifications.indexOf(item);
    // Dismissible yêu cầu bỏ item khỏi danh sách ngay; trả lại chỗ cũ nếu API lỗi.
    setState(() {
      _notifications.remove(item);
    });
    _syncUnreadCount();
    try {
      await _repo.deleteNotification(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notifications.insert(index.clamp(0, _notifications.length), item);
      });
      _syncUnreadCount();
      _showError(_errorText(e));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textPrimary,
        content: Text('🗑️ Đã xoá "${item.title}"'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openRequestDetail(NotificationItem item) async {
    final requestId = item.requestId;
    if (requestId == null || requestId.isEmpty) {
      await _showNotificationDetail(item);
      return;
    }
    try {
      await _repo.markRead(item.id);
      if (!mounted) return;
      setState(() => item.isRead = true);
      _syncUnreadCount();
    } catch (e) {
      _showError(_errorText(e));
    }
    if (!mounted) return;

    final result = await context.push<ShiftRequestStatus>(
      '/notifications/detail',
      extra: {
        'requestId': requestId,
        'title': item.title,
        'senderName': item.senderName ?? '—',
        'senderRole': item.senderRole ?? '',
        'senderPhone': item.senderPhone ?? '',
        'requestType': item.requestType ?? 'cover',
        'requestTime': item.time,
        'shiftName': item.shiftName ?? '—',
        'shiftTime': item.shiftTime ?? '—',
        'shiftHours': item.shiftHours ?? '',
        'shiftDate': item.shiftDate ?? '—',
        'branch': item.branch ?? BranchScope.label(context),
        'shiftRole': item.shiftRole ?? '',
        'swapShiftName': item.swapShiftName,
        'swapShiftTime': item.swapShiftTime,
        'swapShiftHours': item.swapShiftHours,
        'swapShiftDate': item.swapShiftDate,
        'swapShiftBranch': item.swapShiftBranch,
        'swapShiftRole': item.swapShiftRole,
        'reason': item.reason ?? item.content,
        'initialStatus': item.requestStatus,
        'onStatusChanged': (ShiftRequestStatus newStatus) {
          setState(() {
            item.requestStatus = newStatus;
          });
        },
      },
    );

    if (result != null) {
      setState(() {
        item.requestStatus = result;
      });
    }
  }

  Future<void> _showNotificationDetail(NotificationItem item) async {
    try {
      await _repo.markRead(item.id);
      if (!mounted) return;
      setState(() => item.isRead = true);
      _syncUnreadCount();
    } catch (e) {
      _showError(_errorText(e));
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: item.iconColor.withValues(alpha: 0.12),
                  child: FaIcon(item.icon, color: item.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      Text(item.time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              item.content,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
            ),
            if (item.isShiftRequest) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openRequestDetail(item);
                  },
                  icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 15),
                  label: const Text('Xem chi tiết ca & Phản hồi', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteSingle(item);
                    },
                    icon: const FaIcon(FontAwesomeIcons.trashCan, size: 18, color: AppColors.error),
                    label: const Text('Xoá thông báo', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Đóng', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelecting ? _buildSelectionAppBar() : _buildNormalAppBar(unreadCount),
      body: _notifications.isEmpty
          ? RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          _loadError != null ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.bellSlash,
                          size: 64,
                          color: _loadError != null ? AppColors.error : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _loadError ?? 'Không có thông báo nào',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loadError != null ? 'Kéo xuống để thử lại.' : 'Tất cả thông báo đã được dọn sạch.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  return _buildNotificationCard(item);
                },
              ),
            ),
      bottomNavigationBar: _isSelecting ? _buildSelectionBottomBar() : null,
    );
  }

  PreferredSizeWidget _buildNormalAppBar(int unreadCount) {
    return AppBar(
      title: const Text('Thông báo'),
      backgroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const FaIcon(FontAwesomeIcons.checkDouble, color: AppColors.textPrimary),
          tooltip: 'Tùy chọn thông báo',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'read_all') {
              _markAllAsRead();
            } else if (value == 'select_mode') {
              _toggleSelectionMode();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'read_all',
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.envelopeOpen, size: 20, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Đọc hết (Tất cả đã đọc)'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'select_mode',
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.listCheck, size: 20, color: AppColors.textPrimary),
                  SizedBox(width: 10),
                  Text('Đánh dấu & Chọn'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedIds.length;
    final allSelected = count == _notifications.length && _notifications.isNotEmpty;

    return AppBar(
      leading: IconButton(
        icon: const FaIcon(FontAwesomeIcons.xmark, color: AppColors.textPrimary),
        onPressed: _toggleSelectionMode,
      ),
      title: Text(
        count > 0 ? 'Đã chọn $count' : 'Chọn thông báo',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      backgroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: Text(
            allSelected ? 'Bỏ chọn hết' : 'Chọn tất cả',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBottomBar() {
    final count = _selectedIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: count > 0 ? _markSelectedAsRead : null,
                icon: const FaIcon(FontAwesomeIcons.envelopeOpen, size: 18),
                label: const Text('Đọc các mục chọn'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: count > 0 ? _deleteSelected : null,
                icon: const FaIcon(FontAwesomeIcons.trashCan, size: 18),
                label: Text('Xoá ($count)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FaIcon(FontAwesomeIcons.trashCan, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text('Xoá', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      onDismissed: (_) => _deleteSingle(item),
      child: InkWell(
        onTap: () {
          if (_isSelecting) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(item.id);
              } else {
                _selectedIds.add(item.id);
              }
            });
          } else {
            if (item.isShiftRequest) {
              _openRequestDetail(item);
            } else {
              _showNotificationDetail(item);
            }
          }
        },
        onLongPress: () {
          if (!_isSelecting) {
            setState(() {
              _isSelecting = true;
              _selectedIds.add(item.id);
            });
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (item.isRead ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.2)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelecting) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(item.id);
                      } else {
                        _selectedIds.remove(item.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
              ],
              // Icon
              CircleAvatar(
                radius: 20,
                backgroundColor: item.iconColor.withValues(alpha: 0.12),
                child: FaIcon(item.icon, color: item.iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title, content, time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: item.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.time,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (item.isShiftRequest) ...[
                              const SizedBox(width: 8),
                              _buildRequestStatusBadge(item.requestStatus),
                            ],
                          ],
                        ),
                        if (!_isSelecting)
                          InkWell(
                            onTap: () => _deleteSingle(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: FaIcon(FontAwesomeIcons.trashCan, size: 16, color: Colors.grey.shade400),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStatusBadge(ShiftRequestStatus status) {
    Color bg;
    Color text;
    String label;
    switch (status) {
      case ShiftRequestStatus.pending:
        bg = Colors.amber.shade50;
        text = Colors.amber.shade900;
        label = 'Chờ phản hồi';
        break;
      case ShiftRequestStatus.accepted:
        bg = Colors.green.shade50;
        text = Colors.green.shade800;
        label = 'Đã chấp nhận';
        break;
      case ShiftRequestStatus.rejected:
        bg = Colors.red.shade50;
        text = Colors.red.shade800;
        label = 'Đã từ chối';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}
