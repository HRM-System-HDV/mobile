import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Hệ thống Typography Scale chuẩn hóa đồng bộ giữa Web và Mobile.
///
/// Sử dụng chung font chữ Google Fonts: **Public Sans**
/// Đảm bảo kích thước, trọng số font và line-height tương ứng chính xác với Web:
/// - h1: 20px (Bold 700)
/// - h2: 18px (Bold 700)
/// - h3: 16px (SemiBold 600)
/// - h4: 14.5px (SemiBold 600)
/// - body: 14px (Medium 500)
/// - bodySmall: 13px (Medium 500)
/// - caption: 12px (Medium 500)
/// - micro: 11px (Bold 700)
class AppTypography {
  // ── 1. CÁC KIỂU VĂN BẢN ĐỊNH SẴN (TYPOGRAPHY SCALE) ──

  /// Tiêu đề chính trang / AppBar: 20px, Bold (700)
  static TextStyle get h1 => GoogleFonts.publicSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  /// Tiêu đề phân mục lớn / Nhóm chức năng: 18px, Bold (700)
  static TextStyle get h2 => GoogleFonts.publicSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: AppColors.textPrimary,
      );

  /// Tiêu đề thẻ Card, Dialog, Modal: 16px, SemiBold (600)
  static TextStyle get h3 => GoogleFonts.publicSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  /// Tiêu đề phần tử con, tên nhân viên: 14.5px, SemiBold (600)
  static TextStyle get h4 => GoogleFonts.publicSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  /// Văn bản chính (Paragraph / thẻ p): 14px, Medium (500)
  static TextStyle get body => GoogleFonts.publicSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  /// Văn bản chính thu nhỏ: 13px, Medium (500)
  static TextStyle get bodySmall => GoogleFonts.publicSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textPrimary,
      );

  /// Văn bản phụ (Caption / thẻ span / subtitle): 12px, Medium (500)
  static TextStyle get caption => GoogleFonts.publicSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  /// Văn bản siêu nhỏ cho huy hiệu / badge / tag: 11px, Bold (700)
  static TextStyle get micro => GoogleFonts.publicSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  /// Kiểu chữ nút bấm: 13.5px, Bold (700)
  static TextStyle get button => GoogleFonts.publicSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  // ── 2. FLUTTER TEXT THEME CẤU HÌNH CHO TOÀN BỘ ỨNG DỤNG ──
  static TextTheme get textTheme {
    final baseTheme = GoogleFonts.publicSansTextTheme();
    return baseTheme.copyWith(
      headlineLarge: h1,
      headlineMedium: h2,
      headlineSmall: h3,
      titleLarge: h3,
      titleMedium: h4,
      titleSmall: body,
      bodyLarge: body,
      bodyMedium: bodySmall,
      bodySmall: caption,
      labelLarge: button,
      labelMedium: caption,
      labelSmall: micro,
    );
  }
}
