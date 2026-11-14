import '../../core/network/api_client.dart';

class WifiConfigModel {
  final String id;
  final String ssid;
  final String bssid;
  final String branchId;
  final String status;
  final DateTime? createdAt;

  const WifiConfigModel({
    required this.id,
    required this.ssid,
    required this.bssid,
    required this.branchId,
    required this.status,
    this.createdAt,
  });

  factory WifiConfigModel.fromJson(Map<String, dynamic> j) => WifiConfigModel(
        id: j['id']?.toString() ?? '',
        ssid: j['ssid']?.toString() ?? '',
        bssid: j['bssid']?.toString() ?? '',
        branchId: j['branchId']?.toString() ?? '',
        status: j['status']?.toString() ?? 'hoạt động',
        createdAt:
            j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'bssid': bssid,
        'branchId': branchId,
        'status': status,
      };
}

/// Repository cấu hình Wi-Fi chấm công qua api-gateway (4000) về integration-service (4005).
///
/// Hợp đồng: `contentFields.wifiConfig` = ssid, bssid, branchId (UUID), status
/// ("hoạt động" | "vô hiệu hóa"). Toàn bộ tuyến /api/wifi-configs, kể cả GET danh
/// sách, chỉ mở cho admin (IntegrationService.js contentList/contentWrite) —
/// staff/manager gọi sẽ nhận 403 "Chỉ admin được quản trị hệ thống".
class WifiConfigRepository {
  final ApiClient api;
  WifiConfigRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<WifiConfigModel>> getWifiConfigs({String? branchId}) async {
    final data = await api.getJson('/api/wifi-configs', query: {
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    });
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(WifiConfigModel.fromJson)
        .toList();
  }

  Future<WifiConfigModel> createWifiConfig({
    required String ssid,
    required String bssid,
    required String branchId,
    String status = 'hoạt động',
  }) async {
    final res = await api.postJson('/api/wifi-configs', {
      'ssid': ssid,
      'bssid': bssid,
      'branchId': branchId,
      'status': status,
    });
    return WifiConfigModel.fromJson(res is Map<String, dynamic> ? res : const <String, dynamic>{});
  }

  /// Chỉ được chứa ssid, bssid, branchId, status — khóa thừa backend trả 400.
  Future<void> updateWifiConfig(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/wifi-configs/$id', payload);
  }

  Future<void> deleteWifiConfig(String id) async {
    await api.delete('/api/wifi-configs/$id');
  }
}
