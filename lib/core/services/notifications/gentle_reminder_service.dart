import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../data/models/entry.dart';
import '../../../data/models/ritual.dart';

enum ReminderCadence { daily, weekly, biweekly, triweekly, fourWeeks }

extension ReminderCadenceExtension on ReminderCadence {
  int get days {
    switch (this) {
      case ReminderCadence.daily:
        return 1;
      case ReminderCadence.weekly:
        return 7;
      case ReminderCadence.biweekly:
        return 14;
      case ReminderCadence.triweekly:
        return 21;
      case ReminderCadence.fourWeeks:
        return 28;
    }
  }

  String get label {
    switch (this) {
      case ReminderCadence.daily:
        return 'Daily';
      case ReminderCadence.weekly:
        return 'Weekly';
      case ReminderCadence.biweekly:
        return 'Every 2 weeks';
      case ReminderCadence.triweekly:
        return 'Every 3 weeks';
      case ReminderCadence.fourWeeks:
        return 'Every 4 weeks';
    }
  }
}

class ReminderSettings {
  final bool enabled;
  final ReminderCadence cadence;
  final int hour;
  final int minute;
  final int quietStartHour;
  final int quietEndHour;

  const ReminderSettings({
    required this.enabled,
    required this.cadence,
    required this.hour,
    required this.minute,
    required this.quietStartHour,
    required this.quietEndHour,
  });

  const ReminderSettings.defaults()
    : enabled = false,
      cadence = ReminderCadence.weekly,
      hour = 19,
      minute = 30,
      quietStartHour = 21,
      quietEndHour = 8;

  ReminderSettings copyWith({
    bool? enabled,
    ReminderCadence? cadence,
    int? hour,
    int? minute,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      cadence: cadence ?? this.cadence,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
    );
  }
}

class GentleReminderService {
  static const _enabledKey = 'gentle_reminders_enabled';
  static const _cadenceKey = 'gentle_reminders_cadence';
  static const _hourKey = 'gentle_reminders_hour';
  static const _minuteKey = 'gentle_reminders_minute';
  static const _quietStartKey = 'gentle_reminders_quiet_start';
  static const _quietEndKey = 'gentle_reminders_quiet_end';
  static const _notificationId = 7001;
  static const _ritualAntiNagKey = 'ritual_last_notification_ms';

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  GentleReminderService({
    required SharedPreferences prefs,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _prefs = prefs,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  ReminderSettings get settings => ReminderSettings(
    enabled: _prefs.getBool(_enabledKey) ?? false,
    cadence: ReminderCadence.values.byName(
      _prefs.getString(_cadenceKey) ?? ReminderCadence.weekly.name,
    ),
    hour: _prefs.getInt(_hourKey) ?? 19,
    minute: _prefs.getInt(_minuteKey) ?? 30,
    quietStartHour: _prefs.getInt(_quietStartKey) ?? 21,
    quietEndHour: _prefs.getInt(_quietEndKey) ?? 8,
  );

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
    }
    _initialized = true;
  }

  Future<void> saveSettings(ReminderSettings next) async {
    await _prefs.setBool(_enabledKey, next.enabled);
    await _prefs.setString(_cadenceKey, next.cadence.name);
    await _prefs.setInt(_hourKey, next.hour);
    await _prefs.setInt(_minuteKey, next.minute);
    await _prefs.setInt(_quietStartKey, next.quietStartHour);
    await _prefs.setInt(_quietEndKey, next.quietEndHour);
  }

  Future<void> reschedule(List<Entry> entries) async {
    await init();
    await _plugin.cancel(_notificationId);

    final current = settings;
    if (!current.enabled) return;

    final now = DateTime.now();
    DateTime? lastActivity;
    for (final entry in entries) {
      if (entry.isDeleted) continue;
      if (lastActivity == null || entry.createdAt.isAfter(lastActivity)) {
        lastActivity = entry.createdAt;
      }
    }

    final next = computeNextReminderDate(
      now: now,
      lastActivity: lastActivity,
      settings: current,
    );
    if (next == null) return;

    final date = tz.TZDateTime.from(next, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'seedling_gentle_reminders',
        'Gentle reminders',
        channelDescription: 'Occasional gentle reminders to capture memories',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    await _plugin.zonedSchedule(
      _notificationId,
      'A gentle check-in',
      'Capture a memory if something stayed with you today.',
      date,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleRitualReminders(List<Ritual> dueRituals) async {
    await init();

    // Global anti-nag: skip if any notification fired in the last 24 hours.
    final lastMs = _prefs.getInt(_ritualAntiNagKey);
    if (lastMs != null) {
      final lastSent = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(lastSent).inHours < 24) return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'seedling_ritual_reminders',
        'Ritual reminders',
        channelDescription: 'Reminders for your recurring ritual moments',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    int scheduled = 0;
    for (final ritual in dueRituals) {
      final notificationId = 7100 + ritual.id;
      final scheduledTime = tz.TZDateTime.from(
        DateTime.now().add(const Duration(seconds: 30)),
        tz.local,
      );

      await _plugin.zonedSchedule(
        notificationId,
        ritual.name,
        'You usually capture this around now',
        scheduledTime,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduled++;
    }

    if (scheduled > 0) {
      await _prefs.setInt(
        _ritualAntiNagKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  static DateTime? computeNextReminderDate({
    required DateTime now,
    required DateTime? lastActivity,
    required ReminderSettings settings,
  }) {
    if (!settings.enabled) return null;

    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      settings.hour,
      settings.minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    if (lastActivity != null) {
      final minDue = DateTime(
        lastActivity.year,
        lastActivity.month,
        lastActivity.day,
        settings.hour,
        settings.minute,
      ).add(Duration(days: settings.cadence.days));
      if (candidate.isBefore(minDue)) {
        candidate = minDue;
      }
    }

    if (_isInQuietHours(
      hour: candidate.hour,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
    )) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        settings.quietEndHour,
        settings.minute,
      );
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
    }

    return candidate;
  }

  static bool _isInQuietHours({
    required int hour,
    required int quietStartHour,
    required int quietEndHour,
  }) {
    if (quietStartHour == quietEndHour) return false;
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    return hour >= quietStartHour || hour < quietEndHour;
  }
}
