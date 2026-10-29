/// Phiếu lương — khớp schema docs/A §6.
/// `month` định dạng MM-YYYY. `netSalary = baseSalary - totalPenalty`.
/// Chống trùng cặp (employeeId, month) phía server.
class PayslipModel {
  final String id;
  final String employeeId;
  final String month;
  final double baseSalary;
  final double totalPenalty;
  final double netSalary;
  final String? payoutId;
  final String status;
  final String? issuedAt;

  const PayslipModel({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    required this.totalPenalty,
    required this.netSalary,
    this.payoutId,
    required this.status,
    this.issuedAt,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> j) => PayslipModel(
        id: j['id']?.toString() ?? '',
        employeeId: j['employeeId']?.toString() ?? '',
        month: j['month']?.toString() ?? '',
        baseSalary: (j['baseSalary'] as num?)?.toDouble() ?? 0,
        totalPenalty: (j['totalPenalty'] as num?)?.toDouble() ?? 0,
        netSalary: (j['netSalary'] as num?)?.toDouble() ?? 0,
        payoutId: j['payoutId']?.toString(),
        status: j['status']?.toString() ?? '',
        issuedAt: j['issuedAt']?.toString(),
      );
}
