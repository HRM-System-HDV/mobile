import '../../core/network/api_client.dart';

class WifiConfigModel {
  final String id;
  final String ssid;
  final String bssid;
  final String branch;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WifiConfigModel({
    required this.id,
    required this.ssid,
    required this.bssid,
    required this.branch,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory WifiConfigModel.fromJson(Map<String, dynamic> j) => WifiConfigModel(
        id: j['id']?.toString() ?? '',
        ssid: j['ssid']?.toString() ?? '',
        bssid: j['bssid']?.toString() ?? '',
        branch: j['branch']?.toString() ?? '',
        status: j['status']?.toString() ?? 'hoạt động',
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
        updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'].toString()) : null,
      );

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'bssid': bssid,
        'branch': branch,
        'status': status,
      };
}

/// Repository cấu hình Wi-Fi chấm công qua api-gateway (4000) về integration-service (4005).
class WifiConfigRepository {
  final ApiClient api;
  WifiConfigRepository({ApiClient? api}) : api = api ?? ApiClient();

  Future<List<WifiConfigModel>> getWifiConfigs({String? branch}) async {
    final path = branch != null && branch.isNotEmpty
        ? '/api/wifi-configs?branch=${Uri.encodeComponent(branch)}'
        : '/api/wifi-configs';
    final data = await api.getJson(path);
    final List list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(WifiConfigModel.fromJson)
        .toList();
  }

  Future<WifiConfigModel> createWifiConfig({
    required String ssid,
    required String bssid,
    required String branch,
    String status = 'hoạt động',
  }) async {
    final res = await api.postJson('/api/wifi-configs', {
      'ssid': ssid,
      'bssid': bssid,
      'branch': branch,
      'status': status,
    });
    final Map<String, dynamic> map = res is Map<String, dynamic> ? res : {};
    return WifiConfigModel.fromJson(map);
  }

  Future<void> updateWifiConfig(String id, Map<String, dynamic> payload) async {
    await api.putJson('/api/wifi-configs/$id', payload);
  }

  Future<void> deleteWifiConfig(String id) async {
    await api.delete('/api/wifi-configs/$id');
  }
}
