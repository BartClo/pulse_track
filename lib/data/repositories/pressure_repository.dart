import 'package:isar/isar.dart';
import '../../models/pressure_reading.dart';
import '../../models/dashboard_data.dart';
import '../datasources/local_db.dart';
import '../../services/insight_notification_service.dart';
import '../../services/sync_service.dart';

/// Repository that abstracts all database operations for PressureReading.
///
/// This layer isolates the UI from database implementation details.
/// Uses async/await for operations and Streams for reactive updates.
/// Automatically syncs to cloud when user is logged in.
class PressureRepository {
  PressureRepository._();

  static final PressureRepository _instance = PressureRepository._();

  /// Singleton instance of the repository.
  static PressureRepository get instance => _instance;

  Isar get _db => LocalDatabase.instance;

  // ============================================================
  // WRITE OPERATIONS
  // ============================================================

  /// Saves a new pressure reading to the database.
  /// If user is logged in, also syncs to cloud (non-blocking).
  Future<void> saveReading(PressureReading reading) async {
    // 1. Always save locally first (offline-first)
    await _db.writeTxn(() async {
      await _db.pressureReadings.put(reading);
    });

    // 2. Check insights
    final recentReadings = await getReadingsLastDays(2);
    await InsightNotificationService.instance.checkAfterSave(recentReadings);

    // 3. Sync to cloud (non-blocking, fire-and-forget)
    _syncToCloud(reading);
  }

  /// Syncs reading to cloud without blocking UI.
  void _syncToCloud(PressureReading reading) {
    // Fire and forget - don't await
    SyncService.instance.pushReadingToCloud(reading).catchError((e) {
      // Silently handle errors - local save already succeeded
      print('[PressureRepository] Cloud sync failed: $e');
    });
  }

  /// Deletes a reading by its ID.
  Future<bool> deleteReading(int id) async {
    return await _db.writeTxn(() async {
      return await _db.pressureReadings.delete(id);
    });
  }

  /// Deletes all readings from the database.
  Future<void> deleteAllReadings() async {
    await _db.writeTxn(() async {
      await _db.pressureReadings.clear();
    });
  }

  // ============================================================
  // READ OPERATIONS (Futures)
  // ============================================================

  /// Retrieves all pressure readings, sorted by date descending.
  Future<List<PressureReading>> getAllReadings() async {
    return await _db.pressureReadings.where().sortByDateDesc().findAll();
  }

  /// Retrieves readings from the last N days.
  Future<List<PressureReading>> getReadingsLastDays(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return await _db.pressureReadings
        .where()
        .dateGreaterThan(cutoff)
        .sortByDateDesc()
        .findAll();
  }

  /// Gets the most recent reading, or null if none exist.
  Future<PressureReading?> getLatestReading() async {
    return await _db.pressureReadings.where().sortByDateDesc().findFirst();
  }

  // ============================================================
  // REACTIVE STREAMS (Raw - for internal use)
  // ============================================================

  /// Watches all readings and emits updated list on any change.
  /// Limited to last 100 readings for performance.
  Stream<List<PressureReading>> _watchAllReadings() {
    return _db.pressureReadings
        .where()
        .sortByDateDesc()
        .limit(100)
        .watch(fireImmediately: true);
  }

  /// Watches readings for the last N days.
  Stream<List<PressureReading>> _watchLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.pressureReadings
        .where()
        .dateGreaterThan(cutoff)
        .sortByDateDesc()
        .watch(fireImmediately: true);
  }

  // ============================================================
  // DERIVED DATA STREAMS (for UI consumption)
  // ============================================================

  /// Stream of pre-computed dashboard data.
  /// Business logic is computed in the repository, not the UI.
  Stream<DashboardData> watchDashboardData() {
    return _watchLastDays(7).map(DashboardData.fromReadings);
  }

  /// Stream of pre-computed history data.
  /// Limited to 100 readings for performance.
  Stream<HistoryData> watchHistoryData() {
    return _watchAllReadings().map(HistoryData.fromReadings);
  }

  /// Stream of pre-computed chart data for a given period.
  Stream<ChartData> watchChartData(int days) {
    return _watchLastDays(days).map(ChartData.fromReadings);
  }

  // ============================================================
  // LEGACY STREAMS (for backward compatibility)
  // ============================================================

  /// Watches all readings (limited).
  @Deprecated('Use watchHistoryData() instead')
  Stream<List<PressureReading>> watchAllReadings() => _watchAllReadings();

  /// Watches readings for the last N days.
  @Deprecated('Use watchDashboardData() or watchChartData() instead')
  Stream<List<PressureReading>> watchLastDays(int days) => _watchLastDays(days);

  /// Watches today's readings only.
  Stream<List<PressureReading>> watchTodayReadings() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _db.pressureReadings
        .where()
        .dateGreaterThan(startOfDay)
        .sortByDateDesc()
        .watch(fireImmediately: true);
  }
}
