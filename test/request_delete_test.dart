import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/models/user.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/state/user_scope.dart';
import 'package:mobile/src/features/approvals/approval_repository.dart';
import 'package:mobile/src/features/approvals/approvals.dart';
import 'package:mobile/src/features/profile/employee_repository.dart';
import 'repositories/mock_api_client.dart';

Future<MockApiClient> openRequest(WidgetTester tester, {String role = 'manager', String branch = 'branch', String status = 'pending', bool fail = false}) async {
  final api = MockApiClient()..getJsonResponse = [{'id':'request','type':'leave','employeeId':'employee','branchId':branch,'title':'Đơn nghỉ phép','content':'Có việc gia đình','status':status}];
  if (fail) api.deleteHandler = (_) => throw const ApiException('CONFLICT', 'Đơn đã được xử lý', 409);
  final employees = MockApiClient()..getJsonResponse = [];
  final notifier = ValueNotifier<UserModel?>(UserModel(id:'user',name:'Manager',email:'m@example.com',role:role,assignedBranchId:'branch'));
  addTearDown(notifier.dispose);
  await tester.pumpWidget(MaterialApp(home: UserScope(notifier:notifier,child:ShiftRequestScreen(repository:ApprovalRepository(api:api),employeeRepository:EmployeeRepository(api:employees)))));
  await tester.pumpAndSettle();
  if (status == 'approved') {await tester.tap(find.textContaining('Đã duyệt ('));await tester.pumpAndSettle();}
  await tester.tap(find.text('Chi tiết').first);
  await tester.pumpAndSettle();
  return api;
}
void main() {
  testWidgets('confirmation deletes the selected pending request', (tester) async {
    final api = await openRequest(tester);
    await tester.tap(find.text('Xóa đơn'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r)=>r.method=='DELETE'),isEmpty);
    await tester.tap(find.text('Xác nhận xóa'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r)=>r.method=='DELETE').single.path,'/api/requests/request');
    expect(find.text('Đã xóa đơn yêu cầu'),findsOneWidget);
  });
  testWidgets('cancel keeps the pending request', (tester) async {
    final api = await openRequest(tester);
    await tester.tap(find.text('Xóa đơn'));await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));await tester.pumpAndSettle();
    expect(api.requests.where((r)=>r.method=='DELETE'),isEmpty);
    expect(find.text('Xóa đơn'),findsOneWidget);
  });
  testWidgets('server failure keeps the confirmation and record', (tester) async {
    await openRequest(tester,fail:true);
    await tester.tap(find.text('Xóa đơn'));await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận xóa'));await tester.pumpAndSettle();
    expect(find.text('Đơn đã được xử lý'),findsOneWidget);
    await tester.tap(find.text('Hủy'));await tester.pumpAndSettle();
    expect(find.text('Xóa đơn'),findsOneWidget);
  });
  testWidgets('processed requests cannot be deleted', (tester) async {
    await openRequest(tester,status:'approved');
    expect(find.text('Xóa đơn'),findsNothing);
  });
  testWidgets('a manager cannot delete another branch request', (tester) async {
    await openRequest(tester,branch:'other');
    expect(find.text('Xóa đơn'),findsNothing);
  });
}
