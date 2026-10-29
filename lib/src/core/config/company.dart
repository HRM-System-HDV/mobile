import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Cấu hình thông tin doanh nghiệp cố định cho mô hình On-Premises.
///
/// Cả web và mobile gọi chung 1 cửa duy nhất là api-gateway (cổng 4000).
/// [apiBaseUrl] tự động nhận diện môi trường:
/// - Android emulator: dùng `http://10.0.2.2:4000` (trỏ về máy host)
/// - iOS simulator / macOS desktop / Web: dùng `http://localhost:4000`
/// - Thiết bị thật: ghi đè qua `--dart-define=API_BASE_URL=http://<IP_LAN>:4000`
class CompanyConfig {
  static const String companyName = 'Hệ Thống Doanh Nghiệp HRM';
  static const String shortName = 'HRM Enterprise';
  static const String brandCode = 'HRM';
  static const String supportPhone = '1900 1234';

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://localhost:4000';
  }

  /// Timeout gọi liên service theo ràng buộc PTPMDV (tối đa 5000ms).
  static const Duration apiTimeout = Duration(milliseconds: 5000);
}
