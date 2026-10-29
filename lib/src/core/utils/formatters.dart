// Helpers định dạng dùng chung toàn app.

/// Định dạng tiền Việt: 25000000 → "25.000.000₫".
String formatVND(num value) {
  final intVal = value.round();
  final str = intVal.toString();
  final buffer = StringBuffer();
  var count = 0;
  for (var i = str.length - 1; i >= 0; i--) {
    buffer.write(str[i]);
    count++;
    if (count % 3 == 0 && i != 0) buffer.write('.');
  }
  final reversed = buffer.toString().split('').reversed.join();
  return '$reversed₫';
}

/// Định dạng giờ làm: 7.5 → "7h30".
String formatHours(double hours) {
  final h = hours.truncate();
  final m = ((hours - h) * 60).round();
  if (m == 0) return '${h}h';
  return '${h}h${m.toString().padLeft(2, '0')}';
}
