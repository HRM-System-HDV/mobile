import 'dart:convert';
import 'package:flutter/material.dart';

import '../config/company.dart';
import '../network/api_client.dart';

/// Ảnh nội bộ phải đi qua gateway mà app đang cấu hình: URL ghi trong DB là
/// `PUBLIC_BASE_URL` của server (localhost), không với tới được từ emulator
/// hay thiết bị thật, và khác origin nên không gắn được JWT.
String _internalFileUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.path.startsWith('/api/files/')) return url;
  final base = Uri.tryParse(CompanyConfig.apiBaseUrl);
  if (base == null) return url;
  return uri.replace(scheme: base.scheme, host: base.host, port: base.port).toString();
}

/// Hỗ trợ nạp ảnh từ:
/// 1. Chuỗi Data URI base64 (ví dụ: data:image/jpeg;base64,...)
/// 2. Đường dẫn mạng HTTP / HTTPS (máy chủ nội bộ hoặc dịch vụ ngoài)
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
    final url = _internalFileUrl(clean);
    return NetworkImage(url, headers: ApiClient.imageHeadersFor(url));
  }

  return null;
}

