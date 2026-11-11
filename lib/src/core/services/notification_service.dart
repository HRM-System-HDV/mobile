import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/notifications/notification_repository.dart';
import '../../features/schedule/shift_repository.dart';
import '../utils/date_format.dart';

/// Local notification (âm thanh/rung theo cài đặt) + nhắc ca theo giờ.
/// Mọi khóa cài đặt trùng 10 switch trong notif_settings.dart và backend.
class LocalNotifier {
  LocalNotifier._();
  static final LocalNotifier instance = LocalNotifier._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // 4 kênh Android cho 4 tổ hợp âm thanh/rung; iOS chỉnh theo từng thông báo.
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final combo in _channelCombos) {
        await android?.createNotificationChannel(AndroidNotificationChannel(
          combo.$1,
          combo.$2,
          importance: Importance.high,
          playSound: combo.$3,
          enableVibration: combo.$4,
        ));
      }
      await android?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } catch (e) {
      // Không chặn app khi thiết bị không hỗ trợ (ví dụ simulator cũ).
      debugPrint('[LocalNotifier] init lỗi: $e');
    }
  }

  static const _channelCombos = [
    ('hrm_sound_vibrate', 'HRM — Âm thanh & Rung', true, true),
    ('hrm_sound_only', 'HRM — Chỉ âm thanh', true, false),
    ('hrm_vibrate_only', 'HRM — Chỉ rung', false, true),
    ('hrm_silent', 'HRM — Im lặng', false, false),
  ];

  NotificationDetails _details({required bool sound, required bool vibrate}) {
    final combo = _channelCombos.firstWhere((c) => c.$3 == sound && c.$4 == vibrate);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        combo.$1,
        combo.$2,
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound,
        enableVibration: vibrate,
      ),
      // iOS không tách được rung khỏi âm thanh: rung theo cài đặt hệ thống khi có sound.
      iOS: DarwinNotificationDetails(presentSound: sound, presentBadge: true),
    );
  }

  Future<void> show(int id, String title, String body, {bool sound = true, bool vibrate = true}) async {
    if (!_ready) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details(sound: sound, vibrate: vibrate));
    } catch (e) {
      debugPrint('[LocalNotifier] show lỗi: $e');
    }
  }

  Future<void> schedule(int id, DateTime when, String title, String body, {bool sound = true, bool vibrate = true}) async {
    if (!_ready || !when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details(sound: sound, vibrate: vibrate),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[LocalNotifier] schedule lỗi: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}

/// Cache cài đặt thông báo để polling/nhắc ca không phải gọi API mỗi lần.
class NotificationSettingsCache {
  static const defaults = <String, bool>{
    'checkInBefore1Hour': true,
    'checkInBefore30Min': true,
    'checkInBefore10Min': true,
    'checkOutBefore10Min': true,
    'missedCheckOutAfter10Min': true,
    'missedCheckOutAfter30Min': true,
    'missedCheckOutAfter1Hour': true,
    'tabNotificationAlert': true,
    'soundEnabled': true,
    'vibrateEnabled': true,
  };

  static Map<String, bool> _values = Map.of(defaults);

  static bool get(String key) => _values[key] ?? true;

  static void setLocal(String key, bool value) {
    _values = {..._values, key: value};
  }

  static Future<void> refresh({String? userId}) async {
    try {
      final data = await NotificationRepository().getSettings(userId: userId);
      if (data == null) return;
      final next = Map.of(defaults);
      for (final key in defaults.keys) {
        if (data[key] is bool) next[key] = data[key] == true;
      }
      _values = next;
    } catch (_) {
      // Giữ cache hiện có khi mất mạng.
    }
  }
}

/// Lên lịch nhắc check-in/check-out trong ngày theo ca được phân công và cài đặt.
class ShiftReminders {
  static final Set<int> _scheduledIds = {};
  static bool _running = false;

  static int _idFor(String shiftId, int slot) =>
      100000 + (shiftId.hashCode.abs() % 100000) * 8 + slot;

  /// Gọi sau khi tải ca, sau khi chấm công vào/ra, và sau khi đổi cài đặt.
  /// Truyền [shifts] sẵn có để khỏi gọi lại API.
  static Future<void> reschedule({String? employeeId, List<ApiShiftModel>? shifts}) async {
    if (_running) return;
    _running = true;
    try {
      for (final id in _scheduledIds) {
        await LocalNotifier.instance.cancel(id);
      }
      _scheduledIds.clear();

      await NotificationSettingsCache.refresh(userId: employeeId);
      final todayShifts = shifts ?? await ShiftRepository().getShifts(employeeId: employeeId);
      final today = vnDate(DateTime.now());
      final sound = NotificationSettingsCache.get('soundEnabled');
      final vibrate = NotificationSettingsCache.get('vibrateEnabled');

      for (final shift in todayShifts) {
        if (toVnDate(shift.date) != today) continue;
        final start = parseVnDate('$today ${shift.scheduledStart}');
        final end = parseVnDate('$today ${shift.scheduledEnd}');
        final name = shift.template.isNotEmpty ? shift.template : 'Ca làm việc';
        final checkedIn = (shift.checkIn ?? '').isNotEmpty;
        final checkedOut = (shift.checkOut ?? '').isNotEmpty;

        Future<void> put(int slot, DateTime? when, String title, String body) async {
          if (when == null) return;
          final id = _idFor(shift.id, slot);
          await LocalNotifier.instance.schedule(id, when, title, body, sound: sound, vibrate: vibrate);
          _scheduledIds.add(id);
        }

        if (!checkedIn && start != null) {
          if (NotificationSettingsCache.get('checkInBefore1Hour')) {
            await put(0, start.subtract(const Duration(minutes: 60)), 'Sắp đến ca làm ⏰',
                'Ca "$name" bắt đầu lúc ${shift.scheduledStart} — còn 1 tiếng. Nhớ chấm công vào ca!');
          }
          if (NotificationSettingsCache.get('checkInBefore30Min')) {
            await put(1, start.subtract(const Duration(minutes: 30)), 'Sắp đến ca làm ⏰',
                'Ca "$name" bắt đầu lúc ${shift.scheduledStart} — còn 30 phút.');
          }
          if (NotificationSettingsCache.get('checkInBefore10Min')) {
            await put(2, start.subtract(const Duration(minutes: 10)), 'Chuẩn bị vào ca 🔔',
                'Ca "$name" bắt đầu sau 10 phút (${shift.scheduledStart}). Mở app để chấm công!');
          }
        }

        if (!checkedOut && end != null) {
          if (NotificationSettingsCache.get('checkOutBefore10Min')) {
            await put(3, end.subtract(const Duration(minutes: 10)), 'Sắp hết ca 🏁',
                'Ca "$name" kết thúc lúc ${shift.scheduledEnd} — còn 10 phút. Chuẩn bị chấm công ra ca.');
          }
          if (NotificationSettingsCache.get('missedCheckOutAfter10Min')) {
            await put(4, end.add(const Duration(minutes: 10)), 'Quên chấm công ra ca? ⚠️',
                'Ca "$name" đã kết thúc 10 phút trước. Hãy chấm công ra ca ngay!');
          }
          if (NotificationSettingsCache.get('missedCheckOutAfter30Min')) {
            await put(5, end.add(const Duration(minutes: 30)), 'Chưa chấm công ra ca ⚠️',
                'Đã 30 phút kể từ khi hết ca "$name". Chấm công ra để không bị thiếu công.');
          }
          if (NotificationSettingsCache.get('missedCheckOutAfter1Hour')) {
            await put(6, end.add(const Duration(minutes: 60)), 'Khẩn: chưa chấm công ra ca 🚨',
                'Đã 1 tiếng kể từ khi hết ca "$name". Liên hệ quản lý nếu có vấn đề chấm công.');
          }
        }
      }
    } catch (e) {
      debugPrint('[ShiftReminders] reschedule lỗi: $e');
    } finally {
      _running = false;
    }
  }
}