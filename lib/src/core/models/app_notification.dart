/// Thông báo — khớp schema docs/A §6.
/// `targetEmployeeId` null là gửi toàn hệ thống.
class AppNotificationModel {
  final String id;
  final String? targetEmployeeId;
  final String? branchSlug;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final String? requestType;
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
    this.branchSlug,
    required this.title,
    required this.body,
    required this.isRead,
    this.metadata,
    this.requestType,
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
    return AppNotificationModel(
      id: j['id']?.toString() ?? '',
      targetEmployeeId: j['targetEmployeeId']?.toString(),
      branchSlug: j['branchSlug']?.toString() ?? j['branch']?.toString(),
      title: j['title']?.toString() ?? '',
      body: j['body']?.toString() ?? '',
      isRead: j['isRead'] == true,
      metadata: meta is Map ? meta.cast<String, dynamic>() : null,
      requestType: j['requestType']?.toString() ?? j['request_type']?.toString(),
      shiftName: j['shiftName']?.toString() ?? j['shift']?.toString(),
      shiftDate: j['shiftDate']?.toString() ?? j['date']?.toString(),
      shiftTime: j['shiftTime']?.toString() ?? j['time']?.toString(),
      shiftHours: j['shiftHours']?.toString() ?? j['hours']?.toString(),
      senderName: j['senderName']?.toString() ?? j['sender']?.toString(),
      senderRole: j['senderRole']?.toString() ?? j['role']?.toString(),
      senderPhone: j['senderPhone']?.toString() ?? j['phone']?.toString(),
      createdAt: j['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (targetEmployeeId != null) 'targetEmployeeId': targetEmployeeId,
        if (branchSlug != null) 'branchSlug': branchSlug,
        'title': title,
        'body': body,
        'isRead': isRead,
        if (metadata != null) 'metadata': metadata,
        if (requestType != null) 'requestType': requestType,
        if (shiftName != null) 'shiftName': shiftName,
        if (shiftDate != null) 'shiftDate': shiftDate,
        if (shiftTime != null) 'shiftTime': shiftTime,
        if (shiftHours != null) 'shiftHours': shiftHours,
        if (senderName != null) 'senderName': senderName,
        if (senderRole != null) 'senderRole': senderRole,
        if (senderPhone != null) 'senderPhone': senderPhone,
        if (createdAt != null) 'createdAt': createdAt,
      };
}
