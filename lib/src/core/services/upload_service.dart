import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../network/api_client.dart';

class UploadService {
  final ApiClient _api;
  final ImagePicker _picker = ImagePicker();

  UploadService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Cho phép người dùng chụp ảnh từ Camera hoặc chọn từ Thư viện ảnh,
  /// sau đó nén và tải trực tiếp lên Cloudinary thông qua API Gateway (/api/upload).
  Future<String?> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
    String folder = 'hrm',
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final extension = file.name.split('.').last.toLowerCase();
      final mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64Str';

      return await uploadDataUrl(dataUrl, folder: folder);
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  /// Tải trực tiếp chuỗi Data URL (data:image/...;base64,...) lên Cloudinary qua API Gateway.
  Future<String> uploadDataUrl(String dataUrl, {String folder = 'hrm'}) async {
    final res = await _api.postJson('/api/upload', {
      'file': dataUrl,
      'folder': folder,
    });
    final Map<String, dynamic> data = (res is Map && res['data'] is Map)
        ? (res['data'] as Map).cast<String, dynamic>()
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('Không nhận được đường dẫn ảnh từ Cloudinary');
    }
    return url;
  }
}
