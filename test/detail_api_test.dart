import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/features/news/news.dart';
import 'package:mobile/src/features/news/news_repository.dart';
import 'package:mobile/src/features/profile/employee_repository.dart';
import 'package:mobile/src/features/regulations/regulation_repository.dart';
import 'package:mobile/src/features/regulations/regulations.dart';
import 'package:mobile/src/features/salary/salary_repository.dart';
import 'package:mobile/src/features/wifi_config/wifi_config_repository.dart';
import 'repositories/mock_api_client.dart';

const user = UserModel(id: 'user', name: 'Staff', email: 'staff@example.com', role: 'staff');
const listed = {'id': 'record', 'title': 'Tiêu đề', 'summary': 'Tóm tắt', 'content': 'Nội dung cũ', 'tag': 'Thông báo', 'publishDate': '14/11/2026', 'regulationCode': 'QD-1', 'category': 'Nội quy', 'effectiveDate': '14/11/2026'};

void main() {
  test('detail repositories call the ID endpoint and parse fresh data', () async {
    final api = MockApiClient()..getJsonResponse = {...listed, 'content': 'Nội dung mới', 'ssid': 'WiFi mới', 'name': 'Chi nhánh mới', 'netSalary': '1500000'};
    expect((await NewsRepository(api: api).getNewsById('record')).content, 'Nội dung mới');
    expect((await RegulationRepository(api: api).getRegulation('record')).content, 'Nội dung mới');
    expect((await SalaryRepository(api: api).getPayslip('record')).netSalary, 1500000);
    expect((await WifiConfigRepository(api: api).getWifiConfig('record')).ssid, 'WiFi mới');
    expect((await EmployeeRepository(api: api).getBranch('record')).name, 'Chi nhánh mới');
    expect(api.requests.map((r) => r.path), [
      '/api/news/record', '/api/regulations/record', '/api/payroll/payslips/record', '/api/wifi-configs/record', '/api/branches/record',
    ]);
  });

  test('detail repositories propagate server errors and reject the wrong record', () async {
    final api = MockApiClient()..getJsonHandler = (path, query) => throw const ApiException('NOT_FOUND', 'Đã xóa', 404);
    await expectLater(NewsRepository(api: api).getNewsById('record'), throwsA(isA<ApiException>()));
    api.getJsonHandler = null;
    api.getJsonResponse = {'id': 'other'};
    await expectLater(SalaryRepository(api: api).getPayslip('record'), throwsA(isA<ApiException>()));
  });

  for (final isNews in [true, false]) {
    testWidgets('${isNews ? 'news' : 'regulation'} opens fresh detail after loading by ID', (tester) async {
      final detail = Completer<Map<String, dynamic>>();
      final api = MockApiClient()..getJsonHandler = (path, _) => path.endsWith('/record') ? detail.future : [listed];
      final branches = MockApiClient()..getJsonResponse = [];
      await tester.pumpWidget(MaterialApp(home: isNews
          ? NewsScreen(currentUser: user, repository: NewsRepository(api: api), employeeRepository: EmployeeRepository(api: branches))
          : CompanyRegulationsScreen(currentUser: user, repository: RegulationRepository(api: api), employeeRepository: EmployeeRepository(api: branches))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiêu đề').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Đang tải chi tiết...'), findsOneWidget);
      expect(find.text('Nội dung cũ'), findsNothing);
      detail.complete({...listed, 'content': 'Nội dung mới'});
      await tester.pumpAndSettle();
      expect(find.text('Nội dung mới'), findsOneWidget);
      expect(api.requests.last.path, isNews ? '/api/news/record' : '/api/regulations/record');
    });
  }

  testWidgets('a deleted news item shows an error instead of stale detail', (tester) async {
    final api = MockApiClient()..getJsonHandler = (path, _) {
      if (path.endsWith('/record')) throw const ApiException('NOT_FOUND', 'Tin đã bị xóa', 404);
      return [listed];
    };
    final branches = MockApiClient()..getJsonResponse = [];
    await tester.pumpWidget(MaterialApp(home: NewsScreen(currentUser: user, repository: NewsRepository(api: api), employeeRepository: EmployeeRepository(api: branches))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiêu đề').first);
    await tester.pumpAndSettle();
    expect(find.text('Tin đã bị xóa'), findsOneWidget);
    expect(find.text('Nội dung cũ'), findsNothing);
    expect(find.text('Đang tải chi tiết...'), findsNothing);
  });
}
