/// Yêu cầu nội bộ — khớp schema docs/A §6.
/// `type`: leave/overtime/advance/other. `status`: pending/approved/rejected.
/// Duyệt/từ chối tự sinh thông báo. Chỉ xóa khi đang pending.
class LeaveRequestModel {
  final String id;
  final String type;
  final String employeeId;
  final String? branchSlug;
  final String title;
  final String content;
  final String? attachmentUrl;
  final String status;
  final String? reviewedBy;
  final String? reviewNote;
  final String? createdAt;
  final String? updatedAt;

  const LeaveRequestModel({
    required this.id,
    required this.type,
    required this.employeeId,
    this.branchSlug,
    required this.title,
    required this.content,
    this.attachmentUrl,
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
        branchSlug: j['branchSlug']?.toString(),
        title: j['title']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        attachmentUrl: j['attachmentUrl']?.toString(),
        status: j['status']?.toString() ?? 'pending',
        reviewedBy: j['reviewedBy']?.toString(),
        reviewNote: j['reviewNote']?.toString(),
        createdAt: j['createdAt']?.toString(),
        updatedAt: j['updatedAt']?.toString(),
      );
}
