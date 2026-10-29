/// Chấm công — khớp schema docs/A §6.
/// `date` định dạng DD-MM-YYYY. `status`: present/absent/late/early_leave.
class AttendanceModel {
  final String id;
  final String employeeId;
  final String shiftId;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final double penaltyAmount;
  final String? penaltyNote;
  final String status;

  const AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.penaltyAmount,
    this.penaltyNote,
    required this.status,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> j) => AttendanceModel(
        id: j['id']?.toString() ?? '',
        employeeId: j['employeeId']?.toString() ?? '',
        shiftId: j['shiftId']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        checkIn: j['checkIn']?.toString(),
        checkOut: j['checkOut']?.toString(),
        penaltyAmount: (j['penaltyAmount'] as num?)?.toDouble() ?? 0,
        penaltyNote: j['penaltyNote']?.toString(),
        status: j['status']?.toString() ?? 'present',
      );
}
