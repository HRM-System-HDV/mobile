import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/wifi_config/wifi_config_repository.dart';

import 'mock_api_client.dart';

void main() {
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
          'branch': 'q1',
          'status': 'hoạt động',
        }
      ];

      final configs = await repository.getWifiConfigs();

      expect(configs.length, 1);
      final c = configs.first;
      expect(c.id, 'wifi-1');
      expect(c.ssid, 'Coffee_Store_5G');
      expect(c.bssid, 'AA:BB:CC:DD:EE:FF');
      expect(c.branch, 'q1');
      expect(c.status, 'hoạt động');

      expect(mockApi.requests.first.path, '/api/wifi-configs');
    });

    test('fetches with encoded branch query param in path', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'wifi-2',
          'ssid': 'Branch_WiFi',
          'bssid': '11:22:33:44:55:66',
          'branch': 'Chi Nhánh 1',
          'status': 'hoạt động',
        }
      ];

      final configs = await repository.getWifiConfigs(branch: 'Chi Nhánh 1');

      expect(configs.length, 1);
      expect(mockApi.requests.first.path, '/api/wifi-configs?branch=Chi%20Nh%C3%A1nh%201');
    });

    test('propagates ApiException on failure', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('FORBIDDEN', 'Không đủ quyền', 403);
      };

      expect(
        () => repository.getWifiConfigs(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    });
  });

  group('WifiConfigRepository mutations', () {
    test('createWifiConfig sends POST and returns parsed model', () async {
      mockApi.postJsonResponse = {
        'id': 'wifi-new',
        'ssid': 'Office_Main',
        'bssid': '00:11:22:33:44:55',
        'branch': 'hq',
        'status': 'hoạt động',
      };

      final created = await repository.createWifiConfig(
        ssid: 'Office_Main',
        bssid: '00:11:22:33:44:55',
        branch: 'hq',
      );

      expect(created.id, 'wifi-new');
      expect(created.ssid, 'Office_Main');
      expect(created.bssid, '00:11:22:33:44:55');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.method, 'POST');
      expect(req.path, '/api/wifi-configs');
      expect(req.payload?['ssid'], 'Office_Main');
    });

    test('updateWifiConfig sends PUT to /api/wifi-configs/:id', () async {
      mockApi.putJsonResponse = {'success': true};

      await repository.updateWifiConfig('wifi-1', {'status': 'tạm dừng'});

      expect(mockApi.requests.last.method, 'PUT');
      expect(mockApi.requests.last.path, '/api/wifi-configs/wifi-1');
      expect(mockApi.requests.last.payload?['status'], 'tạm dừng');
    });

    test('deleteWifiConfig sends DELETE to /api/wifi-configs/:id', () async {
      await repository.deleteWifiConfig('wifi-1');

      expect(mockApi.requests.last.method, 'DELETE');
      expect(mockApi.requests.last.path, '/api/wifi-configs/wifi-1');
    });

    test('scanNearbyWifi calls /api/wifi-configs/scan', () async {
      mockApi.getJsonResponse = [
        {'ssid': 'Coffee_Store_5G', 'bssid': 'AA:BB:CC:DD:EE:FF'}
      ];

      final results = await repository.scanNearbyWifi();

      expect(results.length, 1);
      expect(results.first['ssid'], 'Coffee_Store_5G');
      expect(mockApi.requests.last.method, 'GET');
      expect(mockApi.requests.last.path, '/api/wifi-configs/scan');
    });
  });
}
