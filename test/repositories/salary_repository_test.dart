import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/salary/salary_repository.dart';

import 'mock_api_client.dart';

const _employeeUuid = '3d4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7080';
const _payslipUuid = '6a7b8c9d-0e1f-2a3b-4c5d-6e7f80910110';
const _payoutUuid = '7b8c9d0e-1f2a-3b4c-5d6e-7f8091011120';

void main() {
  late MockApiClient mockApi;
  late SalaryRepository repository;

  setUp(() {
    mockApi = MockApiClient();
    repository = SalaryRepository(api: mockApi);
  });

  group('SalaryRepository.getPayslips', () {
    test('parses Decimal strings from the payroll service', () async {
      mockApi.getJsonResponse = [
        {
          'id': _payslipUuid,
          'employeeId': _employeeUuid,
          'month': '2026-11',
          'baseSalary': '15000000',
          'bonus': '2000000',
          'totalPenalty': '500000',
          'netSalary': '16500000',
          'salaryType': 'monthly',
          'salaryRate': '15000000',
          'workedHours': null,
          'payoutId': _payoutUuid,
          'status': 'paid',
          'issuedAt': '2026-11-30T06:00:00.000Z',
        }
      ];

      final payslips = await repository.getPayslips(
        employeeId: _employeeUuid,
        month: '2026-11',
      );

      expect(payslips.length, 1);
      final p = payslips.first;
      expect(p.id, _payslipUuid);
      expect(p.employeeId, _employeeUuid);
      expect(p.month, '2026-11');
      expect(p.baseSalary, 15000000.0);
      expect(p.bonus, 2000000.0);
      expect(p.totalPenalty, 500000.0);
      expect(p.netSalary, 16500000.0);
      expect(p.status, 'paid');

      expect(mockApi.requests.length, 1);
      final req = mockApi.requests.first;
      expect(req.path, '/api/payroll/payslips');
      expect(req.query?['employeeId'], _employeeUuid);
      expect(req.query?['month'], '2026-11');
    });

    test('parses wrapped items dictionary and defaults bonus to 0.0 when missing', () async {
      mockApi.getJsonResponse = {
        'items': [
          {
            'id': '8c9d0e1f-2a3b-4c5d-6e7f-809101112130',
            'employeeId': _employeeUuid,
            'month': '2026-10',
            'baseSalary': '10000000',
            'totalPenalty': '0',
            'netSalary': '10000000',
            'status': 'pending_confirmation',
          }
        ]
      };

      final payslips = await repository.getPayslips();

      expect(payslips.length, 1);
      expect(payslips.first.bonus, 0.0);
      expect(payslips.first.status, 'pending_confirmation');
      expect(payslips.first.id, '8c9d0e1f-2a3b-4c5d-6e7f-809101112130');
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
          'id': _payoutUuid,
          'bankReference': 'GD-000001',
          'debitAccountId': '9d0e1f2a-3b4c-5d6e-7f80-910111213140',
          'debitAccountNumber': '1900123456789',
          'totalAmount': '50000000',
          'content': 'Chi lương tháng 11',
          'beneficiaryCount': 5,
          'idempotencyKey': 'idem-key-1',
          'status': 'success',
          'createdAt': '2026-11-30T08:00:00.000Z',
          'payslips': [
            {'id': _payslipUuid}
          ],
        }
      ];

      final payouts = await repository.getPayouts();

      expect(payouts.length, 1);
      final po = payouts.first;
      expect(po.id, _payoutUuid);
      expect(po.bankReference, 'GD-000001');
      expect(po.debitAccountNumber, '1900123456789');
      expect(po.totalAmount, 50000000.0);
      expect(po.beneficiaryCount, 5);
      expect(po.deduped, isFalse);

      expect(mockApi.requests.first.path, '/api/payroll/payouts');
    });
  });
}
