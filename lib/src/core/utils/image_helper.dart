import 'dart:convert';
import 'package:flutter/material.dart';

/// Hỗ trợ nạp ảnh từ:
/// 1. Chuỗi Data URI base64 (ví dụ: data:image/jpeg;base64,...)
/// 2. Đường dẫn mạng HTTP / HTTPS (ví dụ: Cloudinary, S3, web server)
ImageProvider? parseImageProvider(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final clean = raw.trim();

  // Trường hợp chuỗi base64 data URI
  if (clean.startsWith('data:image/') && clean.contains(';base64,')) {
    try {
      final base64String = clean.split(';base64,').last.trim();
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  // Trường hợp link mạng HTTP / HTTPS
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return NetworkImage(clean);
  }

  return null;
}

