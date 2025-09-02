import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final macOSInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final init = InitializationSettings(
      android: androidInit, 
      iOS: iosInit,
      macOS: macOSInit,
    );
    await _plugin.initialize(init);
    _ready = true;
  }

  static Future<void> scheduleBookingReminder({
    required int bookingId,
    required DateTime startUtc,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    // напомним за 10 минут
    final whenLocal = startUtc.toLocal().subtract(const Duration(minutes: 10));
    if (whenLocal.isBefore(DateTime.now())) return;

    const android = AndroidNotificationDetails(
      'bookings', 'Брони', channelDescription: 'Напоминания о бронях',
      importance: Importance.defaultImportance, priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    const macOS = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: android, 
      iOS: ios,
      macOS: macOS,
    );

    await _plugin.zonedSchedule(
      bookingId,
      title,
      body,
      tz.TZDateTime.from(whenLocal, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'booking:$bookingId',
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}