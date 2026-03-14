import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps flutter_local_notifications for phase-triggered partner reminders.
///
/// All notification IDs are stable so re-scheduling replaces the previous
/// notification rather than stacking duplicates.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'cycle_reminders';
  static const _channelName = 'Cycle Reminders';

  // Stable notification IDs
  static const _idPeriodStarted = 1;
  static const _idPeriodSoon = 2;
  static const _idPeriodEnded = 3;
  static const _idFertileWindow = 4;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }

    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }

    return false;
  }

  /// Fires immediately — used when period just started.
  Future<void> notifyPeriodStarted(String partnerName) async {
    await _showImmediate(
      id: _idPeriodStarted,
      title: '${partnerName.isNotEmpty ? partnerName : 'Your partner'} just started their period',
      body: 'Be extra kind today — small gestures mean everything right now.',
    );
  }

  /// Fires immediately — used when period ended.
  Future<void> notifyPeriodEnded(String partnerName) async {
    await _showImmediate(
      id: _idPeriodEnded,
      title: 'Period ended',
      body: '${partnerName.isNotEmpty ? partnerName : 'They'} might be feeling much better.',
    );
  }

  /// Schedules a notification 2 days before the expected next period.
  Future<void> schedulePeriodSoonReminder(DateTime nextPeriodDate) async {
    final reminderDate = nextPeriodDate.subtract(const Duration(days: 2));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    await _plugin.zonedSchedule(
      _idPeriodSoon,
      'Period expected in 2 days',
      'Great time to prep snacks and be extra patient.',
      tz.TZDateTime.from(reminderDate, tz.local),
      _buildDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules a notification on the fertile window start date.
  Future<void> scheduleFertileWindowReminder(DateTime fertileStart) async {
    final now = DateTime.now();
    if (fertileStart.isBefore(now)) return;

    await _plugin.zonedSchedule(
      _idFertileWindow,
      'Fertile window starts today',
      'High energy phase — great time for connection.',
      tz.TZDateTime.from(fertileStart, tz.local),
      _buildDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(id, title, body, _buildDetails());
  }

  NotificationDetails _buildDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }
}
