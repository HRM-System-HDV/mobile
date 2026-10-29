/// Thông báo — khớp schema docs/A §6.
/// `targetEmployeeId` null là gửi toàn hệ thống.
class AppNotificationModel {
  final String id;
  final String? targetEmployeeId;
  final String? branchSlug;
  final String title;
  final String body;
  final bool isRead;
  final String? createdAt;

  const AppNotificationModel({
    required this.id,
    this.targetEmployeeId,
    this.branchSlug,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> j) =>
      AppNotificationModel(
        id: j['id']?.toString() ?? '',
        targetEmployeeId: j['targetEmployeeId']?.toString(),
        branchSlug: j['branchSlug']?.toString(),
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        isRead: j['isRead'] == true,
        createdAt: j['createdAt']?.toString(),
      );
}
