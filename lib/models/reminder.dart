import 'package:isar/isar.dart';

part 'reminder.g.dart';

/// Model representing a daily reminder for blood pressure measurement.
///
/// Each reminder has a specific time (hour:minute) and can be enabled/disabled.
@collection
class Reminder {
  Id id = Isar.autoIncrement;

  /// Hour of the reminder (0-23)
  int hour;

  /// Minute of the reminder (0-59)
  int minute;

  /// Whether the reminder is currently active
  bool enabled;

  /// Display label for the reminder (e.g., "Mañana", "Noche", "Tarde")
  String label;

  @Index()
  DateTime createdAt;

  Reminder({
    required this.hour,
    required this.minute,
    this.enabled = true,
    required this.label,
    required this.createdAt,
  });

  /// Returns formatted time string like "08:00"
  @ignore
  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Returns the notification message
  @ignore
  String get notificationMessage {
    return 'Recibirás una notificación todos los días a las $formattedTime';
  }

  /// Suggests a label based on the hour
  static String suggestLabel(int hour) {
    if (hour >= 5 && hour < 12) return 'Mañana';
    if (hour >= 12 && hour < 18) return 'Tarde';
    return 'Noche';
  }

  /// Creates a copy with updated fields
  Reminder copyWith({int? hour, int? minute, bool? enabled, String? label}) {
    final newReminder = Reminder(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      createdAt: createdAt,
    );
    newReminder.id = id;
    return newReminder;
  }
}
