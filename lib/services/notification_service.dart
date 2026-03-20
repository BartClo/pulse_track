import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/reminder.dart';
import '../data/repositories/reminder_repository.dart';

/// Global navigator key for navigating from notification callbacks
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Service that manages local notifications for reminders.
///
/// Handles scheduling, canceling, and updating daily notifications.
/// Supports alarm-like behavior with full-screen intent and snooze.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  
  /// Callback for when alarm screen should be shown
  static void Function(int reminderId, String label)? onAlarmTriggered;

  /// Initializes the notification service.
  /// Must be called once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Set local timezone
    try {
      final String timeZoneName = await _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to a default timezone
      tz.setLocalLocation(tz.getLocation('America/New_York'));
    }

    // Android settings with alarm sound
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );

    // Create the notification channel on Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
  }

  Future<String> _getLocalTimeZone() async {
    // Try to get the device timezone
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;

      // Common timezone mappings based on offset
      if (offset.inHours == -5) return 'America/New_York';
      if (offset.inHours == -6) return 'America/Chicago';
      if (offset.inHours == -7) return 'America/Denver';
      if (offset.inHours == -8) return 'America/Los_Angeles';
      if (offset.inHours == -3) return 'America/Sao_Paulo';
      if (offset.inHours == -4) return 'America/Santiago';
      if (offset.inHours == 1) return 'Europe/Paris';
      if (offset.inHours == 0) return 'Europe/London';

      return 'America/New_York'; // Default fallback
    } catch (e) {
      return 'America/New_York';
    }
  }

  Future<void> _createNotificationChannel() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Main alarm channel with maximum priority (uses default alarm sound)
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_channel',
          'Alarmas',
          description: 'Alarmas para medir presión arterial',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF1E88E5),
        ),
      );

      // Regular reminders channel
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminders_channel',
          'Recordatorios',
          description: 'Recordatorios para medir presión arterial',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF1E88E5),
        ),
      );
    }
  }

  /// Called when a notification is tapped (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _handleNotificationPayload(response.payload);
  }

  /// Called when notification is tapped from background
  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationResponse response) {
    debugPrint('Background notification tapped: ${response.payload}');
    // This will be handled when app opens
  }

  /// Parse payload and trigger alarm screen
  void _handleNotificationPayload(String? payload) {
    if (payload == null) return;

    if (payload.startsWith('reminder_')) {
      final idStr = payload.replaceFirst('reminder_', '');
      final id = int.tryParse(idStr);
      if (id != null && onAlarmTriggered != null) {
        // Get reminder label from database
        ReminderRepository.instance.getReminderById(id).then((reminder) {
          if (reminder != null) {
            onAlarmTriggered!(id, reminder.label);
          }
        });
      }
    } else if (payload.startsWith('snooze_')) {
      final idStr = payload.replaceFirst('snooze_', '');
      final id = int.tryParse(idStr);
      if (id != null && onAlarmTriggered != null) {
        onAlarmTriggered!(id, 'Recordatorio');
      }
    }
  }

  /// Requests permission to show notifications (iOS/Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permission
      final notificationGranted =
          await android?.requestNotificationsPermission();

      // Request exact alarm permission for Android 12+
      final exactAlarmGranted = await android?.requestExactAlarmsPermission();

      return (notificationGranted ?? false) && (exactAlarmGranted ?? true);
    } else if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Checks if notifications are permitted
  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Schedules a daily alarm notification for the given reminder.
  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.enabled) {
      await cancelReminder(reminder.id);
      return;
    }

    final scheduledTime = _nextInstanceOfTime(reminder.hour, reminder.minute);

    debugPrint('Scheduling alarm ${reminder.id} for $scheduledTime');

    await _notifications.zonedSchedule(
      reminder.id,
      '⏰ PulseTrack - ${reminder.label}',
      'Es hora de medir tu presión arterial',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarmas',
          channelDescription: 'Alarmas para medir presión arterial',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([
            0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000
          ]),
          enableLights: true,
          ledColor: const Color(0xFF1E88E5),
          ledOnMs: 1000,
          ledOffMs: 500,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ongoing: true,
          autoCancel: false,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'stop',
              'Detener',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'snooze',
              'Posponer 5 min',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
          styleInformation: const BigTextStyleInformation(
            'Es momento de registrar tu medición de presión arterial.\n\n'
            'Toca para abrir la app y registrar tu medición.',
            contentTitle: '⏰ Hora de medir tu presión',
            summaryText: 'PulseTrack',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reminder_${reminder.id}',
    );
  }

  /// Schedules a snooze notification for 5 minutes from now.
  Future<void> scheduleSnooze(int originalReminderId, String label) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
    final snoozeId = originalReminderId + 10000; // Unique ID for snooze

    debugPrint('Scheduling snooze $snoozeId for $snoozeTime');

    await _notifications.zonedSchedule(
      snoozeId,
      '⏰ PulseTrack - $label (Pospuesto)',
      'Recordatorio pospuesto - Es hora de medir tu presión',
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarmas',
          channelDescription: 'Alarmas para medir presión arterial',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([
            0, 1000, 500, 1000, 500, 1000
          ]),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'snooze_$originalReminderId',
    );
  }

  /// Cancels a scheduled notification for the given reminder ID.
  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
    // Also cancel any potential snooze
    await _notifications.cancel(id + 10000);
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  /// Syncs all reminders with the notification scheduler.
  /// Called when the app starts or when reminders change.
  Future<void> syncAllReminders() async {
    final reminders = await ReminderRepository.instance.getAllReminders();

    // Cancel all existing
    await cancelAllReminders();

    // Schedule enabled ones
    for (final reminder in reminders) {
      if (reminder.enabled) {
        await scheduleReminder(reminder);
      }
    }
  }

  /// Gets the next instance of a specific time.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Shows an immediate test alarm notification.
  Future<void> showTestNotification() async {
    await _notifications.show(
      999,
      '⏰ PulseTrack - Prueba',
      '¡Las alarmas están funcionando correctamente!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarmas',
          channelDescription: 'Canal de prueba',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          ongoing: true,
          autoCancel: false,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'stop',
              'Detener',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_alarm',
    );

    // Trigger alarm screen after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (onAlarmTriggered != null) {
        onAlarmTriggered!(999, 'Prueba');
      }
    });
  }
}
