/// Lệnh chi — payroll-service `payouts`.
/// `id` là UUID, `bankReference` dạng GD-000001, `debitAccountNumber` là số tài khoản
/// trích nợ. Trùng `idempotencyKey` trả bản ghi cũ kèm `deduped: true`.
/// Hết số dư HTTP 422.
class PayoutModel {
  final String id;
  final String bankReference;
  final String debitAccountNumber;
  final double totalAmount;
  final String content;
  final int beneficiaryCount;
  final String idempotencyKey;
  final String status;
  final String? createdAt;
  final bool deduped;

  const PayoutModel({
    required this.id,
    required this.bankReference,
    required this.debitAccountNumber,
    required this.totalAmount,
    required this.content,
    required this.beneficiaryCount,
    required this.idempotencyKey,
    required this.status,
    this.createdAt,
    this.deduped = false,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> j) => PayoutModel(
        id: j['id']?.toString() ?? '',
        bankReference: j['bankReference']?.toString() ?? '',
        debitAccountNumber: j['debitAccountNumber']?.toString() ?? '',
        totalAmount: double.tryParse(j['totalAmount']?.toString() ?? '') ?? 0.0,
        content: j['content']?.toString() ?? '',
        beneficiaryCount: int.tryParse(j['beneficiaryCount']?.toString() ?? '') ?? 0,
        idempotencyKey: j['idempotencyKey']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        createdAt: j['createdAt']?.toString(),
        deduped: j['deduped'] == true,
      );
}
