import '../../core/models/app_notification.dart';
import '../../core/network/api_client.dart';

/// Repository thông báo gọi qua api-gateway về integration-service (4005).
class NotificationRepository {
  final ApiClient api;
  NotificationRepository({ApiClient? api}) : api = api ?? ApiClient();

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

  Future<void> markRead(String id) =>
      api.putJson('/api/notifications/$id/read', {});

  Future<void> deleteNotification(String id) =>
      api.delete('/api/notifications/$id');

  Future<Map<String, dynamic>?> getSettings({String? userId}) async {
    final query = <String, String>{};
    if (userId != null && userId.isNotEmpty) query['userId'] = userId;
    final res = await api.getJson('/api/notifications/settings', query: query);
    return res is Map<String, dynamic> ? res : null;
  }

  Future<Map<String, dynamic>?> updateSettings(Map<String, dynamic> payload) async {
    final res = await api.putJson('/api/notifications/settings', payload);
    return res is Map<String, dynamic> ? res : null;
  }
}
