import '../../core/models/app_notification.dart';
import '../../core/network/api_client.dart';

/// Repository thông báo gọi qua api-gateway về integration-service (4005).
///
/// Backend chỉ có: GET/POST /api/notifications, PUT /api/notifications/:id/read,
/// GET/PUT /api/notifications/settings, POST /api/notifications/reminders.
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

  Future<List<AppNotificationModel>> getNotifications({String? employeeId}) async {
    final data = await api.getJson('/api/notifications', query: {
      if (employeeId != null) 'employeeId': employeeId,
    });
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
    final query = <String, String>{};
    if (userId != null && userId.isNotEmpty) query['userId'] = userId;
    final res = await api.getJson('/api/notifications/settings', query: query);
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
