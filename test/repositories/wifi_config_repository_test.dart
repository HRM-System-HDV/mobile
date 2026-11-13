import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/wifi_config/wifi_config_repository.dart';

import 'mock_api_client.dart';

void main() {
  const branchUuid = '3f2b6c1e-9d4a-4f77-8a51-2c0b6f1d4e90';

  late MockApiClient mockApi;
  late WifiConfigRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = WifiConfigRepository(api: mockApi);
  });

  group('WifiConfigRepository.getWifiConfigs', () {
    test('fetches without branch param', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'wifi-1',
          'ssid': 'Coffee_Store_5G',
          'bssid': 'AA:BB:CC:DD:EE:FF',
          'branchId': branchUuid,
          'status': 'hoạt động',
        }
      ];

      final configs = await repository.getWifiConfigs();

      expect(configs.length, 1);
      final c = configs.first;
      expect(c.id, 'wifi-1');
      expect(c.ssid, 'Coffee_Store_5G');
      expect(c.bssid, 'AA:BB:CC:DD:EE:FF');
      expect(c.branchId, branchUuid);
      expect(c.status, 'hoạt động');

      expect(mockApi.requests.first.path, '/api/wifi-configs');
      expect(mockApi.requests.first.query, isEmpty);
    });

    test('filters by branchId query param', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'wifi-2',
          'ssid': 'Branch_WiFi',
          'bssid': '11:22:33:44:55:66',
          'branchId': branchUuid,
          'status': 'hoạt động',
        }
      ];

      final configs = await repository.getWifiConfigs(branchId: branchUuid);

      expect(configs.length, 1);
      expect(mockApi.requests.first.path, '/api/wifi-configs');
      expect(mockApi.requests.first.query, {'branchId': branchUuid});
    });

    test('propagates ApiException on failure', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('FORBIDDEN', 'Chỉ admin được quản trị hệ thống', 403);
      };

      expect(
        () => repository.getWifiConfigs(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });

  group('WifiConfigRepository mutations', () {
    test('createWifiConfig sends only contract keys', () async {
      mockApi.postJsonResponse = {
        'id': 'wifi-new',
        'ssid': 'Office_Main',
        'bssid': '00:11:22:33:44:55',
        'branchId': branchUuid,
        'status': 'hoạt động',
      };

      final created = await repository.createWifiConfig(
        ssid: 'Office_Main',
        bssid: '00:11:22:33:44:55',
        branchId: branchUuid,
      );

      expect(created.id, 'wifi-new');
      expect(created.ssid, 'Office_Main');
      expect(created.bssid, '00:11:22:33:44:55');
      expect(created.branchId, branchUuid);

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/wifi-configs');
      expect(req.payload?.keys.toSet(), {'ssid', 'bssid', 'branchId', 'status'});
      expect(req.payload?['branchId'], branchUuid);
    });

    test('updateWifiConfig sends PUT to /api/wifi-configs/:id', () async {
      mockApi.putJsonResponse = {'id': 'wifi-1', 'status': 'vô hiệu hóa'};

      await repository.updateWifiConfig('wifi-1', {'status': 'vô hiệu hóa'});

      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/wifi-configs/wifi-1');
      expect(mockApi.requests.last.payload?['status'], 'vô hiệu hóa');
    });

    test('deleteWifiConfig sends DELETE to /api/wifi-configs/:id', () async {
      await repository.deleteWifiConfig('wifi-1');

      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/wifi-configs/wifi-1');
    });
  });
}
