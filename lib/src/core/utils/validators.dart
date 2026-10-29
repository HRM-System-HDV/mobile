// Validators dùng chung cho form đăng nhập / hồ sơ.
bool isValidEmail(String value) {
  final v = value.trim();
  if (!v.contains('@')) return false;
  final parts = v.split('@');
  return parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.');
}

bool isValidPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 9 && digits.length <= 12;
}

bool isValidPassword(String value) => value.length >= 6;
