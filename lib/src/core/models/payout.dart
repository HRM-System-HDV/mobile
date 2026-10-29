/// Lệnh chi — khớp schema docs/A §6.
/// `id` dạng TXN-xxxxxx, `bankReference` dạng BANK-xxxxxxxx.
/// Trùng `idempotencyKey` trả bản ghi cũ kèm `deduped: true`. Hết số dư HTTP 422.
class PayoutModel {
  final String id;
  final String bankReference;
  final String debitAccount;
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
    required this.debitAccount,
    required this.totalAmount,
    required this.content,
    required this.beneficiaryCount,
    required this.idempotencyKey,
    required this.status,
    this.createdAt,
    this.deduped = false,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> j) => PayoutModel(
        id: j['id']?.toString() ?? j['transactionId']?.toString() ?? '',
        bankReference: j['bankReference']?.toString() ?? '',
        debitAccount: j['debitAccount']?.toString() ?? '',
        totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
        content: j['content']?.toString() ?? '',
        beneficiaryCount: (j['beneficiaryCount'] as num?)?.toInt() ?? 0,
        idempotencyKey: j['idempotencyKey']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        createdAt: j['createdAt']?.toString(),
        deduped: j['deduped'] == true,
      );
}
