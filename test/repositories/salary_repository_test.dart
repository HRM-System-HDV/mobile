import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/salary/salary_repository.dart';

import 'mock_api_client.dart';

void main() {
  late MockApiClient mockApi;
  late SalaryRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = SalaryRepository(api: mockApi);
  });

  group('SalaryRepository.getPayslips', () {
    test('fetches and deserializes payslips including bonus field from list response', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'ps-101',
          'employeeId': 'emp-1',
          'month': '11-2026',
          'baseSalary': 15000000,
          'bonus': 2000000,
          'totalPenalty': 500000,
          'netSalary': 16500000,
          'payoutId': 'TXN-001',
          'status': 'paid',
          'issuedAt': '2026-11-30',
        }
      ];

      final payslips = await repository.getPayslips(employeeId: 'emp-1', month: '11-2026');

      expect(payslips.length, 1);
      final p = payslips.first;
      expect(p.id, 'ps-101');
      expect(p.employeeId, 'emp-1');
      expect(p.month, '11-2026');
      expect(p.baseSalary, 15000000.0);
      expect(p.bonus, 2000000.0);
      expect(p.totalPenalty, 500000.0);
      expect(p.netSalary, 16500000.0);
      expect(p.status, 'paid');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.path, '/api/payroll/payslips');
      expect(req.query?['employeeId'], 'emp-1');
      expect(req.query?['month'], '11-2026');
    });

    test('parses wrapped items dictionary and defaults bonus to 0.0 when missing', () async {
      mockApi.getJsonResponse = {
        'items': [
          {
            'id': 'ps-102',
            'employeeId': 'emp-2',
            'month': '10-2026',
            'baseSalary': 10000000,
            'totalPenalty': 0,
            'netSalary': 10000000,
            'status': 'pending',
          }
        ]
      };

      final payslips = await repository.getPayslips();

      expect(payslips.length, 1);
      expect(payslips.first.bonus, 0.0);
      expect(payslips.first.id, 'ps-102');
    });

    test('propagates ApiException on error', () async {
      mockApi.getJsonHandler = (path, query) {
        throw const ApiException('NETWORK_ERROR', 'Mất kết nối', 503);
      };

      expect(
        () => repository.getPayslips(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
      );
    });
  });

  group('SalaryRepository.getPayouts', () {
    test('fetches and deserializes payouts', () async {
      mockApi.getJsonResponse = [
        {
          'id': 'TXN-901',
          'bankReference': 'BANK-12345678',
          'debitAccount': '1900123456789',
          'totalAmount': 50000000,
          'content': 'Chi lương tháng 11',
          'beneficiaryCount': 5,
          'idempotencyKey': 'idem-key-1',
          'status': 'success',
          'deduped': true,
        }
      ];

      final payouts = await repository.getPayouts();

      expect(payouts.length, 1);
      final po = payouts.first;
      expect(po.id, 'TXN-901');
      expect(po.bankReference, 'BANK-12345678');
      expect(po.totalAmount, 50000000.0);
      expect(po.beneficiaryCount, 5);
      expect(po.deduped, true);

      expect(mockApi.requests.first.path, '/api/payroll/payouts');
    });
  });
}
