/// Phiếu lương — payroll-service `payslips`.
/// `month` định dạng YYYY-MM. `netSalary = baseSalary + bonus - totalPenalty`.
/// Decimal gửi về dạng chuỗi, `status`: pending_confirmation/confirmed/paid.
/// Chống trùng cặp (employeeId, month) phía server.
class PayslipModel {
  final String id;
  final String employeeId;
  final String month;
  final double baseSalary;
  final double bonus;
  final double totalPenalty;
  final double netSalary;
  final String? payoutId;
  final String status;
  final String? issuedAt;
  final String? confirmedAt;

  const PayslipModel({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    this.bonus = 0.0,
    required this.totalPenalty,
    required this.netSalary,
    this.payoutId,
    required this.status,
    this.issuedAt,
    this.confirmedAt,
  });

  static double _amount(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  factory PayslipModel.fromJson(Map<String, dynamic> j) => PayslipModel(
        id: j['id']?.toString() ?? '',
        employeeId: j['employeeId']?.toString() ?? '',
        month: j['month']?.toString() ?? '',
        baseSalary: _amount(j['baseSalary']),
        bonus: _amount(j['bonus']),
        totalPenalty: _amount(j['totalPenalty']),
        netSalary: _amount(j['netSalary']),
        payoutId: j['payoutId']?.toString(),
        status: j['status']?.toString() ?? '',
        issuedAt: j['issuedAt']?.toString(),
        confirmedAt: j['confirmedAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'month': month,
        'baseSalary': baseSalary,
        'bonus': bonus,
        'totalPenalty': totalPenalty,
        'netSalary': netSalary,
        if (payoutId != null) 'payoutId': payoutId,
        'status': status,
        if (issuedAt != null) 'issuedAt': issuedAt,
        if (confirmedAt != null) 'confirmedAt': confirmedAt,
      };
}
