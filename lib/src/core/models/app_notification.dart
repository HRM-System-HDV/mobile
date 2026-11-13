/// Thông báo — khớp bảng `notifications` của integration-service.
///
/// Cột thật: id, targetEmployeeId, branchId, title, body, isRead, metadata,
/// requestType, requestId, senderId, senderName, createdAt. Phần hiển thị chi tiết
/// (tên ca, ngày, giờ, số giờ, SĐT, vai trò người gửi) do backend nhét vào `metadata`.
class AppNotificationModel {
  final String id;
  final String? targetEmployeeId;
  final String? branchId;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final String? requestType;
  final String? requestId;
  final String? shiftName;
  final String? shiftDate;
  final String? shiftTime;
  final String? shiftHours;
  final String? senderName;
  final String? senderRole;
  final String? senderPhone;
  final String? createdAt;

  const AppNotificationModel({
    required this.id,
    this.targetEmployeeId,
    this.branchId,
    required this.title,
    required this.body,
    required this.isRead,
    this.metadata,
    this.requestType,
    this.requestId,
    this.shiftName,
    this.shiftDate,
    this.shiftTime,
    this.shiftHours,
    this.senderName,
    this.senderRole,
    this.senderPhone,
    this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> j) {
    final meta = j['metadata'];
    final Map<String, dynamic> metadata =
        meta is Map ? meta.cast<String, dynamic>() : const <String, dynamic>{};
    String? metaText(String key) {
      final value = metadata[key];
      return (value == null || value.toString().trim().isEmpty) ? null : value.toString();
    }

    return AppNotificationModel(
      id: j['id']?.toString() ?? '',
      targetEmployeeId: j['targetEmployeeId']?.toString(),
      branchId: j['branchId']?.toString(),
      title: j['title']?.toString() ?? '',
      body: j['body']?.toString() ?? '',
      isRead: j['isRead'] == true,
      metadata: meta is Map ? meta.cast<String, dynamic>() : null,
      requestType: j['requestType']?.toString(),
      requestId: j['requestId']?.toString(),
      shiftName: metaText('shiftName'),
      shiftDate: metaText('shiftDate'),
      shiftTime: metaText('shiftTime'),
      shiftHours: metaText('shiftHours'),
      senderName: j['senderName']?.toString(),
      senderRole: metaText('senderRole'),
      senderPhone: metaText('senderPhone'),
      createdAt: j['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (targetEmployeeId != null) 'targetEmployeeId': targetEmployeeId,
        if (branchId != null) 'branchId': branchId,
        'title': title,
        'body': body,
        'isRead': isRead,
        if (metadata != null) 'metadata': metadata,
        if (requestType != null) 'requestType': requestType,
        if (requestId != null) 'requestId': requestId,
        if (senderName != null) 'senderName': senderName,
        if (createdAt != null) 'createdAt': createdAt,
      };
}
