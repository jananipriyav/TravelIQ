import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Schedules local, on-device "time to leave" reminders for each leg of
/// a trip. These are NOT push notifications — nothing goes through a
/// server, so this works entirely for free with no backend setup.
///
/// This package only supports Android/iOS, not web — every public method
/// here checks kIsWeb first and no-ops instead of crashing, so testing
/// in Chrome never breaks the rest of the app.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Android 13+ requires the user to explicitly grant notification
  /// permission at runtime — this triggers that prompt.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Schedules a single reminder. Silently skips anything already in
  /// the past (e.g. a stop so soon there's no time for a "leave now"
  /// warning).
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) return;
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'departure_reminders',
      'Departure Reminders',
      channelDescription: 'Reminds you when it\'s time to leave for your next stop',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}