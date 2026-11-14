import '../../core/models/app_notification.dart';
import '../../core/network/api_client.dart';

/// Repository thông báo gọi qua api-gateway về integration-service (4005).
///
/// Backend có: GET/POST /api/notifications, PUT /api/notifications/:id/read,
/// PUT /api/notifications/read-all, GET/PUT /api/notifications/settings,
/// POST /api/notifications/reminders (integration-service/src/app.js:50-56).
/// KHÔNG có DELETE /api/notifications/:id.
class NotificationRepository {
  final ApiClient api;
  NotificationRepository({ApiClient? api}) : api = api ?? ApiClient();

  static const List<String> _settingFields = [
    'checkInBefore1Hour',
    'checkInBefore30Min',
    'checkInBefore10Min',
    'checkOutBefore10Min',
    'missedCheckOutAfter10Min',
    'missedCheckOutAfter30Min',
    'missedCheckOutAfter1Hour',
    'tabNotificationAlert',
    'soundEnabled',
    'vibrateEnabled',
  ];

  Future<List<AppNotificationModel>> getNotifications() async {
    // Backend lọc theo employeeId lấy từ access token và bỏ qua query, nên không
    // gửi ?employeeId= (integration-service/src/app.js:53 -> listNotifications đọc
    // who.employeeId; IntegrationService.js:201).
    final data = await api.getJson('/api/notifications');
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationModel.fromJson)
        .toList();
  }

  /// Backend đánh dấu đã đọc theo từng thông báo; chỉ chủ nhân của bản ghi gọi được.
  Future<void> markRead(String id) =>
      api.putJson('/api/notifications/$id/read', {});

  Future<Map<String, dynamic>?> getSettings({String? userId}) async {
    // Backend suy ra người dùng từ access token (who.userId) và bỏ qua query, nên
    // không gửi ?userId= (integration-service/src/app.js:50 -> notificationSettings).
    // Giữ tham số userId vì caller NotificationSettingsCache.refresh (core/services,
    // ngoài phạm vi sửa) vẫn truyền vào; giá trị này không còn được dùng tới.
    final res = await api.getJson('/api/notifications/settings');
    return res is Map<String, dynamic> ? res : null;
  }

  Future<Map<String, dynamic>?> updateSettings(Map<String, dynamic> payload) async {
    final body = <String, dynamic>{
      for (final key in _settingFields)
        if (payload[key] is bool) key: payload[key],
    };
    final res = await api.putJson('/api/notifications/settings', body);
    return res is Map<String, dynamic> ? res : null;
  }
}
