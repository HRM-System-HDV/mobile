// Helpers định dạng ngày dùng chung toàn app — chuẩn DD/MM/YYYY.
//
// Quy ước toàn dự án: mọi ngày lịch hiển thị và mọi payload gửi backend đều là
// DD/MM/YYYY; nếu có giờ thì DD/MM/YYYY HH:mm. Không dùng ISO (yyyy-MM-dd) hay
// dd-MM-yyyy trên bề mặt người dùng.
//
// Các hàm đều thuần Dart, không phụ thuộc package ngoài.

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 02/10/2026
String vnDate(DateTime d) => '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';

/// 02/10/2026 14:05
String vnDateTime(DateTime d) =>
    '${vnDate(d)} ${_pad2(d.hour)}:${_pad2(d.minute)}';

class _ParsedDate {
  final DateTime date;
  final bool hasTime;
  const _ParsedDate(this.date, this.hasTime);
}

final RegExp _hasLeadingYear = RegExp(r'^\s*\d{4}\s*[-/]');
final RegExp _isoLike = RegExp(
  r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?',
);
final RegExp _dayFirst = RegExp(
  r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?',
);
final RegExp _timezoneSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// Parse "khoan dung" cho mọi định dạng legacy:
/// YYYY-MM-DD, YYYY-MM-DDTHH:mm:ss, DD-MM-YYYY, D/M/YYYY, DD/MM/YYYY HH:mm.
/// Trả về null khi không đọc được.
_ParsedDate? _parseAny(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;

  // ISO có múi giờ (Z hoặc ±HH:mm): đổi về giờ máy để hiển thị đúng.
  if (_timezoneSuffix.hasMatch(s)) {
    final dt = DateTime.tryParse(s);
    if (dt != null) return _ParsedDate(dt.toLocal(), s.contains(':'));
  }

  if (_hasLeadingYear.hasMatch(s)) {
    final m = _isoLike.firstMatch(s);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    final hasTime = m.group(4) != null;
    final h = int.tryParse(m.group(4) ?? '0') ?? 0;
    final mi = int.tryParse(m.group(5) ?? '0') ?? 0;
    final sec = int.tryParse(m.group(6) ?? '0') ?? 0;
    final date = DateTime(y, mo, d, hasTime ? h : 0, hasTime ? mi : 0, hasTime ? sec : 0);
    return _ParsedDate(date, hasTime);
  }

  // Day-first: DD/MM/YYYY hoặc DD-MM-YYYY (kèm giờ nếu có).
  final m = _dayFirst.firstMatch(s);
  if (m != null) {
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    final hasTime = m.group(4) != null;
    final h = int.tryParse(m.group(4) ?? '0') ?? 0;
    final mi = int.tryParse(m.group(5) ?? '0') ?? 0;
    final sec = int.tryParse(m.group(6) ?? '0') ?? 0;
    final date = DateTime(y, mo, d, hasTime ? h : 0, hasTime ? mi : 0, hasTime ? sec : 0);
    return _ParsedDate(date, hasTime);
  }

  return null;
}

/// Chuẩn hoá bất kỳ chuỗi ngày nào về DD/MM/YYYY.
/// - YYYY-MM-DD, YYYY-MM-DDTHH:mm:ss → DD/MM/YYYY
/// - DD-MM-YYYY, D/M/YYYY → DD/MM/YYYY
/// - Chuỗi rỗng/null → ''
/// - Không parse được → trả về bản trim ban đầu (không tự bịa ngày).
String toVnDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return '';
  final parsed = _parseAny(s);
  if (parsed == null) return s;
  return vnDate(parsed.date);
}

/// Như [toVnDate] nhưng giữ HH:mm nếu đầu vào có giờ.
String toVnDateTime(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return '';
  final parsed = _parseAny(s);
  if (parsed == null) return s;
  return parsed.hasTime ? vnDateTime(parsed.date) : vnDate(parsed.date);
}

/// Parse tolerant về DateTime local, dùng cho date picker / so sánh ngày.
/// Hỗ trợ các định dạng của [toVnDate] cùng 'DD/MM/YYYY HH:mm'.
DateTime? parseVnDate(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;
  return _parseAny(s)?.date;
}
