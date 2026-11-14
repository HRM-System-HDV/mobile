import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/api_client.dart';
import 'package:mobile/src/core/services/attendance_wifi.dart';
import 'package:mobile/src/features/attendance/attendance_repository.dart';
import 'package:mobile/src/features/attendance/double_attendance.dart';
import 'package:mobile/src/features/attendance/double_attendance_button.dart';
import 'package:mobile/src/features/schedule/shift_repository.dart';
import 'repositories/mock_api_client.dart';

final now = DateTime.parse('2026-11-14T12:00:00+07:00');
const config = {
  'allowDoubleCheckin': true,
  'doubleCheckinEarlyMinutes': 5,
  'doubleCheckinLateMinutes': 5,
  'checkoutWindowMinutes': 60
};
Map<String, dynamic> shift(String id,
        {String day = '14/11/2026',
        String start = '07:00',
        String end = '12:00',
        String employee = 'employee',
        bool checkedIn = true,
        bool checkedOut = false,
        String status = 'đang làm'}) =>
    {
      'id': id,
      'employeeId': employee,
      'branchId': 'branch',
      'workDate': day,
      'templateId': 'template',
      'scheduledStart': start,
      'scheduledEnd': end,
      'status': status,
      'canCheckout': checkedIn && !checkedOut,
      'attendance': checkedIn
          ? {
              'id': 'attendance-$id',
              'shiftId': id,
              'checkIn': '2026-11-14T00:00:00Z',
              'checkOut': checkedOut ? '2026-11-14T05:00:00Z' : null
            }
          : null,
    };
ApiShiftModel? select(List<Map<String, dynamic>> rows,
        {Map<String, dynamic> settings = config, DateTime? at}) =>
    nextDoubleAttendanceShift(
        shifts: rows.map(ApiShiftModel.fromJson).toList(),
        employeeId: 'employee',
        currentShiftId: 'first',
        config: settings,
        now: at ?? now);

class DeviceWifi extends AttendanceWifi {
  bool allowed = true;
  int reads = 0;
  @override
  Future<Map<String, String>> read() async {
    reads++;
    if (!allowed) {
      throw const ApiException(
          'WIFI_UNAVAILABLE', 'Wi-Fi hiện tại không hợp lệ', 400);
    }
    return {'ssid': 'Office', 'bssid': 'aa:bb:cc:dd:ee:ff'};
  }
}

void main() {
  test(
      'only adjacent, unstarted shifts of the same employee qualify inside the configured window',
      () {
    final first = shift('first');
    final next = shift('next', start: '12:00', end: '17:00', checkedIn: false);
    expect(select([first, next])?.id, 'next');
    expect(
        select([
          first,
          {...next, 'scheduledStart': '12:01'}
        ]),
        isNull);
    expect(
        select([
          first,
          {...next, 'employeeId': 'other'}
        ]),
        isNull);
    expect(
        select([
          first,
          {...next, 'status': 'đã hủy'}
        ]),
        isNull);
    expect(
        select([
          first,
          {...next, 'attendance': first['attendance']}
        ]),
        isNull);
    expect(
        select([first, next],
            settings: {...config, 'allowDoubleCheckin': false}),
        isNull);
    expect(select([first, next], settings: {}), isNull);
    expect(select([first, next], at: now.subtract(const Duration(minutes: 6))),
        isNull);
    expect(
        select([first, next], at: now.add(const Duration(minutes: 6))), isNull);
    expect(
        select([first, next],
            settings: {...config, 'doubleCheckinLateMinutes': 120},
            at: now.add(const Duration(minutes: 60))),
        isNull);
  });
  test('overnight shifts join on the following work date', () {
    final first = shift('first', start: '22:00', end: '06:00');
    final next = shift('next',
        day: '15/11/2026', start: '06:00', end: '10:00', checkedIn: false);
    expect(
        select([first, next], at: DateTime.parse('2026-11-15T06:00:00+07:00'))
            ?.id,
        'next');
  });

  testWidgets(
      'keeps ordinary checkout and submits a single atomic double request with live Wi-Fi',
      (tester) async {
    var rows = [
      shift('first'),
      shift('next', start: '12:00', end: '17:00', checkedIn: false)
    ];
    final api = MockApiClient()
      ..getJsonHandler = (path, _) => path.endsWith('/config') ? config : rows;
    final reply = Completer<Map<String, dynamic>>();
    api.postJsonHandler = (_, payload) => reply.future;
    final wifi = DeviceWifi();
    var refreshed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      const Text('Ra ca'),
      DoubleAttendanceButton(
          employeeId: 'employee',
          currentShiftId: 'first',
          now: () => now,
          shiftRepository: ShiftRepository(api: api),
          attendanceRepository: AttendanceRepository(api: api, wifi: wifi),
          onChanged: () async {
            refreshed++;
          }),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('Ra ca'), findsOneWidget);
    await tester.tap(find.text('Ra ca & vào ca tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    final posts = api.requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(1));
    expect(posts.single.path, '/api/attendance/double');
    expect(posts.single.payload, {
      'employeeId': 'employee',
      'shiftId': 'first',
      'nextShiftId': 'next',
      'wifi': {'ssid': 'Office', 'bssid': 'aa:bb:cc:dd:ee:ff'}
    });
    expect(wifi.reads, 1);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đang chấm công...'))
            .onPressed,
        isNull);
    rows = [
      shift('first', checkedOut: true),
      shift('next', start: '12:00', end: '17:00')
    ];
    reply.complete({'previous': rows[0], 'next': rows[1]});
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(
        find.text('Đã ra ca trước và vào ca tiếp thành công.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'bad Wi-Fi prevents the request and keeps a clear error in the confirmation',
      (tester) async {
    final api = MockApiClient()
      ..getJsonHandler = (path, _) => path.endsWith('/config')
          ? config
          : [
              shift('first'),
              shift('next', start: '12:00', end: '17:00', checkedIn: false)
            ];
    final wifi = DeviceWifi()..allowed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DoubleAttendanceButton(
                employeeId: 'employee',
                currentShiftId: 'first',
                now: () => now,
                shiftRepository: ShiftRepository(api: api),
                attendanceRepository:
                    AttendanceRepository(api: api, wifi: wifi),
                onChanged: () async {}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ra ca & vào ca tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Wi-Fi hiện tại không hợp lệ'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
