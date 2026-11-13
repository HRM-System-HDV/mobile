/// Chấm công — khớp bản ghi `attendances` của work-service.
///
/// `workDate` là ngày làm việc (backend trả ISO `YYYY-MM-DD`).
/// `checkIn`/`checkOut` là mốc thời gian ISO có múi giờ, KHÔNG phải 'HH:mm'.
/// `penaltyAmount`/`earnedSalary` là Decimal nên backend trả về DẠNG CHUỖI;
/// `workedSeconds` là số giây đã làm.
/// `status`: present | late | early_leave | late_early_leave | missed.
class AttendanceModel {
  final String id;
  final String employeeId;
  final String shiftId;
  final String workDate;
  final String? checkIn;
  final String? checkOut;
  final double penaltyAmount;
  final double? earnedSalary;
  final double? workedSeconds;
  final String? penaltyNote;
  final String status;

  const AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.workDate,
    this.checkIn,
    this.checkOut,
    this.penaltyAmount = 0,
    this.earnedSalary,
    this.workedSeconds,
    this.penaltyNote,
    required this.status,
  });

  /// Decimal/JSON number đều về được double; chuỗi null/rỗng thì coi là null.
  static double? _num(dynamic value) => double.tryParse(value?.toString() ?? '');

  factory AttendanceModel.fromJson(Map<String, dynamic> j) => AttendanceModel(
        id: j['id']?.toString() ?? '',
        employeeId: j['employeeId']?.toString() ?? '',
        shiftId: j['shiftId']?.toString() ?? '',
        workDate: j['workDate']?.toString() ?? '',
        checkIn: j['checkIn']?.toString(),
        checkOut: j['checkOut']?.toString(),
        penaltyAmount: _num(j['penaltyAmount']) ?? 0,
        earnedSalary: _num(j['earnedSalary']),
        workedSeconds: _num(j['workedSeconds']),
        penaltyNote: j['penaltyNote']?.toString(),
        status: j['status']?.toString() ?? 'present',
      );
}
