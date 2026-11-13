/// Yêu cầu nội bộ — integration-service `types` = leave/advance/shift_swap/work_supplement.
/// `status`: pending/approved/rejected. Id và branchId/employeeId là UUID.
/// Duyệt/từ chối tự sinh thông báo. Chỉ xóa khi đang pending.
class LeaveRequestModel {
  final String id;
  final String type;
  final String employeeId;
  final String? branchId;
  final String title;
  final String content;
  final String? attachmentUrl;
  final String? leaveStartDate;
  final String? leaveEndDate;
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final String? createdAt;
  final String? updatedAt;

  const LeaveRequestModel({
    required this.id,
    required this.type,
    required this.employeeId,
    this.branchId,
    required this.title,
    required this.content,
    this.attachmentUrl,
    this.leaveStartDate,
    this.leaveEndDate,
    required this.status,
    this.reviewedBy,
    this.reviewNote,
    this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> j) => LeaveRequestModel(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'leave',
        employeeId: j['employeeId']?.toString() ?? '',
        branchId: j['branchId']?.toString(),
        title: j['title']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        attachmentUrl: j['attachmentUrl']?.toString(),
        leaveStartDate: j['leaveStartDate']?.toString(),
        leaveEndDate: j['leaveEndDate']?.toString(),
        status: j['status']?.toString() ?? 'pending',
        reviewedBy: j['reviewedBy']?.toString(),
        reviewNote: j['reviewNote']?.toString(),
        createdAt: j['createdAt']?.toString(),
        updatedAt: j['updatedAt']?.toString(),
      );
}
