import 'package:shared_preferences/shared_preferences.dart';
import '../models/pressure_reading.dart';
import 'notification_service.dart';

class InsightNotificationService {
  InsightNotificationService._();

  static final InsightNotificationService instance =
      InsightNotificationService._();

  static const _highAlertKey = 'insight_high_last_sent';
  static const _lowAlertKey = 'insight_low_last_sent';
  static const _inactiveAlertKey = 'insight_inactive_last_sent';
  static const _dailyCheckKey = 'insight_daily_check_last_run';

  Future<void> checkAfterSave(List<PressureReading> recentReadings) async {
    await _checkConditions(recentReadings, includeInactivity: false);
  }

  Future<void> runDailyCheck(List<PressureReading> recentReadings) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayTag = '${today.year}-${today.month}-${today.day}';
    final lastRun = prefs.getString(_dailyCheckKey);
    if (lastRun == todayTag) return;

    await prefs.setString(_dailyCheckKey, todayTag);
    await _checkConditions(recentReadings, includeInactivity: true);
  }

  Future<void> _checkConditions(
    List<PressureReading> readings, {
    required bool includeInactivity,
  }) async {
    if (readings.isEmpty) {
      if (includeInactivity) {
        await _sendIfAllowed(
          key: _inactiveAlertKey,
          cooldown: const Duration(hours: 6),
          id: 4303,
          title: 'PulseTrack',
          body: 'No has registrado tu presión hoy',
          payload: 'insight_inactivity',
        );
      }
      return;
    }

    final recent = [...readings]..sort((a, b) => b.date.compareTo(a.date));

    final lastThree = recent.take(3).toList();
    final hasThreeHigh = lastThree.length == 3 &&
        lastThree.every((r) => r.systolic >= 130 || r.diastolic >= 80);
    if (hasThreeHigh) {
      await _sendIfAllowed(
        key: _highAlertKey,
        cooldown: const Duration(hours: 6),
        id: 4301,
        title: 'PulseTrack',
        body: 'Se detectaron varias mediciones altas recientes',
        payload: 'insight_high',
      );
    }

    final hasLowRecent =
        recent.take(5).any((r) => r.systolic < 90 || r.diastolic < 60);
    if (hasLowRecent) {
      await _sendIfAllowed(
        key: _lowAlertKey,
        cooldown: const Duration(hours: 6),
        id: 4302,
        title: 'PulseTrack',
        body: 'Se detectó una medición baja',
        payload: 'insight_low',
      );
    }

    if (includeInactivity) {
      final latest = recent.first.date;
      final inactive = DateTime.now().difference(latest) >=
          const Duration(hours: 24);
      if (inactive) {
        await _sendIfAllowed(
          key: _inactiveAlertKey,
          cooldown: const Duration(hours: 6),
          id: 4303,
          title: 'PulseTrack',
          body: 'No has registrado tu presión. Ingresa una medición.',
          payload: 'insight_inactivity',
        );
      }
    }
  }

  Future<void> _sendIfAllowed({
    required String key,
    required Duration cooldown,
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastIso = prefs.getString(key);
    if (lastIso != null) {
      final last = DateTime.tryParse(lastIso);
      if (last != null && now.difference(last) < cooldown) return;
    }

    await NotificationService.instance.showInsightNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
    await prefs.setString(key, now.toIso8601String());
  }
}
