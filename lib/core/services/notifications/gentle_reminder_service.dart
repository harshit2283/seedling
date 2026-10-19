import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../constants/prefs_keys.dart';

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
  static const _notificationId = 7001;

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  GentleReminderService({
    required SharedPreferences prefs,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _prefs = prefs,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  ReminderSettings get settings => ReminderSettings(
    enabled: _prefs.getBool(PrefsKeys.gentleRemindersEnabled) ?? false,
    cadence: ReminderCadence.values.byName(
      _prefs.getString(PrefsKeys.gentleRemindersCadence) ??
          ReminderCadence.weekly.name,
    ),
    hour: _prefs.getInt(PrefsKeys.gentleRemindersHour) ?? 19,
    minute: _prefs.getInt(PrefsKeys.gentleRemindersMinute) ?? 30,
    quietStartHour: _prefs.getInt(PrefsKeys.gentleRemindersQuietStart) ?? 21,
    quietEndHour: _prefs.getInt(PrefsKeys.gentleRemindersQuietEnd) ?? 8,
  );

  bool _permissionRequested = false;

  /// Prepares the notification plugin. Cheap to call repeatedly and does not
  /// prompt the user; the OS permission prompt only appears once reminders
  /// are actually enabled (see [reschedule]).
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> _requestPermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
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
  }

  Future<void> saveSettings(ReminderSettings next) async {
    await _prefs.setBool(PrefsKeys.gentleRemindersEnabled, next.enabled);
    await _prefs.setString(PrefsKeys.gentleRemindersCadence, next.cadence.name);
    await _prefs.setInt(PrefsKeys.gentleRemindersHour, next.hour);
    await _prefs.setInt(PrefsKeys.gentleRemindersMinute, next.minute);
    await _prefs.setInt(
      PrefsKeys.gentleRemindersQuietStart,
      next.quietStartHour,
    );
    await _prefs.setInt(PrefsKeys.gentleRemindersQuietEnd, next.quietEndHour);
  }

  Future<void> reschedule(List<Entry> entries) async {
    await init();
    await _plugin.cancel(_notificationId);

    final current = settings;
    if (!current.enabled) return;
    await _requestPermissionOnce();

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

  static const _resurfaceNotificationId = 7002;

  /// Lock-screen-safe resurfacing copy. Deliberately generic: no memory text,
  /// title or date ever appears outside the app.
  static const String resurfaceNotificationTitle =
      'A memory is waiting for you';
  static const String resurfaceNotificationBody =
      'Something from your tree, whenever you have a quiet moment.';

  /// Schedules (or cancels) the opt-in weekly resurfacing nudge. It repeats
  /// weekly at the same day and time; it is only scheduled while [enabled]
  /// and while the tree actually has a memory to bring back ([hasMemory]).
  Future<void> scheduleResurfacingNudge({
    required bool enabled,
    required bool hasMemory,
    DateTime? now,
  }) async {
    await init();
    await _plugin.cancel(_resurfaceNotificationId);
    if (!enabled || !hasMemory) return;
    await _requestPermissionOnce();

    final next = computeNextResurfaceDate(now ?? DateTime.now());
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'seedling_resurfacing',
        'Memories from your tree',
        channelDescription: 'An occasional nudge to revisit a past memory',
        importance: Importance.low,
        priority: Priority.low,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    await _plugin.zonedSchedule(
      _resurfaceNotificationId,
      resurfaceNotificationTitle,
      resurfaceNotificationBody,
      tz.TZDateTime.from(next, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// The next Sunday at 10:00 strictly after [now]: a slow, unhurried moment
  /// of the week, well outside any quiet hours.
  static DateTime computeNextResurfaceDate(
    DateTime now, {
    int weekday = DateTime.sunday,
    int hour = 10,
    int minute = 0,
  }) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    final daysAhead = (weekday - now.weekday) % 7;
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + daysAhead,
      hour,
      minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 7,
        hour,
        minute,
      );
    }
    return candidate;
  }

  /// Lock-screen-safe ritual notification copy. Ritual names are often
  /// lifted from memory text, so they never appear in a notification.
  static const String ritualNotificationTitle = 'A ritual moment';
  static const String ritualNotificationBody =
      'You usually capture something around now.';

  /// Schedule reminders for rituals the user confirmed and keeps active.
  /// Detected patterns are only ever suggestions: an unsaved candidate
  /// (id 0) or a paused/archived ritual never gets a notification.
  Future<void> scheduleRitualReminders(List<Ritual> dueRituals) async {
    final confirmed = dueRituals
        .where((r) => r.id != 0 && r.status == RitualStatus.active)
        .toList();
    if (confirmed.isEmpty) return;
    await init();

    // Global anti-nag: skip if any notification fired in the last 24 hours.
    final lastMs = _prefs.getInt(PrefsKeys.ritualLastNotificationMs);
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
        // On a secure lock screen Android shows only "Contents hidden".
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    int scheduled = 0;
    for (final ritual in confirmed) {
      final notificationId = 7100 + ritual.id;
      final scheduledTime = tz.TZDateTime.from(
        DateTime.now().add(const Duration(seconds: 30)),
        tz.local,
      );

      await _plugin.zonedSchedule(
        notificationId,
        ritualNotificationTitle,
        ritualNotificationBody,
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
        PrefsKeys.ritualLastNotificationMs,
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
