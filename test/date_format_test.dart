import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/utils/date_format.dart';

void main() {
  test('vnDate/vnDateTime luôn DD/MM/YYYY', () {
    expect(vnDate(DateTime(2026, 10, 2)), '02/10/2026');
    expect(vnDateTime(DateTime(2026, 10, 2, 14, 5)), '02/10/2026 14:05');
  });

  test('toVnDate chuẩn hóa mọi định dạng cũ', () {
    expect(toVnDate('2026-10-02'), '02/10/2026');
    expect(toVnDate('02-10-2026'), '02/10/2026');
    expect(toVnDate('2/10/2026'), '02/10/2026');
    expect(toVnDate(null), '');
    expect(toVnDate('Không phải ngày'), 'Không phải ngày');
  });

  test('toVnDateTime giữ giờ khi có, không tự thêm 00:00', () {
    expect(toVnDateTime('2026-10-02T14:05:00'), '02/10/2026 14:05');
    expect(toVnDateTime('02/10/2026'), '02/10/2026');
    expect(toVnDateTime('02/10/2026 08:30'), '02/10/2026 08:30');
  });

  test('timestamp ISO có Z được đổi về giờ máy', () {
    final raw = DateTime(2026, 10, 2, 7, 5).toUtc().toIso8601String();
    expect(toVnDateTime(raw), '02/10/2026 07:05');
  });

  test('parseVnDate đọc được ngày DD/MM/YYYY và ISO', () {
    final vn = parseVnDate('02/10/2026 14:05')!;
    expect([vn.year, vn.month, vn.day, vn.hour, vn.minute], [2026, 10, 2, 14, 5]);
    final iso = parseVnDate('2026-10-02')!;
    expect([iso.year, iso.month, iso.day], [2026, 10, 2]);
    expect(parseVnDate(''), isNull);
  });
}
