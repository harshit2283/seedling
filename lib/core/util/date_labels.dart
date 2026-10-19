import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The one place Seedling turns a moment into words.
///
/// Days are compared on the calendar, never by hours elapsed: a memory from
/// 8 pm last night is "Yesterday" at 9 am, and a day that is 23 or 25 hours
/// long (daylight-saving changes) still counts as one day.
///
/// Times follow the locale (`DateFormat.jm`), or a 24-hour clock when the
/// platform asks for one ([MediaQueryData.alwaysUse24HourFormat]).
class DateLabels {
  const DateLabels._();

  /// Whole calendar days from [earlier]'s date to [later]'s date (local
  /// wall-clock dates). Immune to DST because it compares dates in UTC.
  static int calendarDaysBetween(DateTime earlier, DateTime later) {
    final a = DateTime.utc(earlier.year, earlier.month, earlier.day);
    final b = DateTime.utc(later.year, later.month, later.day);
    return b.difference(a).inDays;
  }

  /// "8:10 PM" (or "20:10" with [use24h] / a 24-hour locale).
  static String time(DateTime at, {String? locale, bool use24h = false}) {
    final format = use24h ? DateFormat.Hm(locale) : DateFormat.jm(locale);
    return format.format(at);
  }

  /// "Today" / "Yesterday" / "Tuesday" (within a week) / "Mar 4" (this
  /// year) / "Mar 4, 2023". A future date falls through to the plain date.
  static String day(DateTime at, {DateTime? now, String? locale}) {
    final reference = now ?? DateTime.now();
    final diff = calendarDaysBetween(at, reference);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return DateFormat.EEEE(locale).format(at);
    if (at.year == reference.year) return DateFormat.MMMd(locale).format(at);
    return DateFormat.yMMMd(locale).format(at);
  }

  /// [day] plus the time for anything inside the last week:
  /// "Today, 8:10 PM", "Yesterday, 8:10 PM", "Tuesday, 8:10 PM".
  /// Older memories show only their date; the time matters less by then.
  static String dayAndTime(
    DateTime at, {
    DateTime? now,
    String? locale,
    bool use24h = false,
  }) {
    final reference = now ?? DateTime.now();
    final label = day(at, now: reference, locale: locale);
    final diff = calendarDaysBetween(at, reference);
    if (diff < 0 || diff >= 7) return label;
    return '$label, ${time(at, locale: locale, use24h: use24h)}';
  }

  /// Like [dayAndTime] but always includes the time, for places where the
  /// time is the point (the capture sheet's "when" line, import previews).
  static String dayWithTime(
    DateTime at, {
    DateTime? now,
    String? locale,
    bool use24h = false,
  }) {
    final label = day(at, now: now, locale: locale);
    return '$label, ${time(at, locale: locale, use24h: use24h)}';
  }

  /// The locale tag and 24-hour preference for [context].
  static ({String? locale, bool use24h}) settingsOf(BuildContext context) {
    return (
      locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
      use24h: MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false,
    );
  }

  static String timeOf(BuildContext context, DateTime at) {
    final s = settingsOf(context);
    return time(at, locale: s.locale, use24h: s.use24h);
  }

  static String dayOf(BuildContext context, DateTime at) {
    return day(at, locale: settingsOf(context).locale);
  }

  static String dayAndTimeOf(BuildContext context, DateTime at) {
    final s = settingsOf(context);
    return dayAndTime(at, locale: s.locale, use24h: s.use24h);
  }

  static String dayWithTimeOf(BuildContext context, DateTime at) {
    final s = settingsOf(context);
    return dayWithTime(at, locale: s.locale, use24h: s.use24h);
  }
}
