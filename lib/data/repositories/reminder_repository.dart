import 'package:isar/isar.dart';
import '../../models/reminder.dart';
import '../datasources/local_db.dart';

/// Repository that abstracts all database operations for Reminders.
///
/// This layer isolates the UI from database implementation details.
/// Uses async/await for operations and Streams for reactive updates.
class ReminderRepository {
  ReminderRepository._();

  static final ReminderRepository _instance = ReminderRepository._();

  /// Singleton instance of the repository.
  static ReminderRepository get instance => _instance;

  Isar get _db => LocalDatabase.instance;

  // ============================================================
  // WRITE OPERATIONS
  // ============================================================

  /// Adds a new reminder to the database.
  Future<int> addReminder(Reminder reminder) async {
    return await _db.writeTxn(() async {
      return await _db.reminders.put(reminder);
    });
  }

  /// Removes a reminder by its ID.
  Future<bool> removeReminder(int id) async {
    return await _db.writeTxn(() async {
      return await _db.reminders.delete(id);
    });
  }

  /// Toggles the enabled state of a reminder.
  Future<void> toggleReminder(int id, bool enabled) async {
    await _db.writeTxn(() async {
      final reminder = await _db.reminders.get(id);
      if (reminder != null) {
        reminder.enabled = enabled;
        await _db.reminders.put(reminder);
      }
    });
  }

  /// Updates a reminder with new values.
  Future<void> updateReminder(Reminder reminder) async {
    await _db.writeTxn(() async {
      await _db.reminders.put(reminder);
    });
  }

  // ============================================================
  // READ OPERATIONS (Futures)
  // ============================================================

  /// Retrieves all reminders, sorted by hour then minute.
  Future<List<Reminder>> getAllReminders() async {
    return await _db.reminders.where().sortByHour().thenByMinute().findAll();
  }

  /// Retrieves only enabled reminders.
  Future<List<Reminder>> getEnabledReminders() async {
    return await _db.reminders
        .filter()
        .enabledEqualTo(true)
        .sortByHour()
        .thenByMinute()
        .findAll();
  }

  /// Gets a reminder by ID.
  Future<Reminder?> getReminderById(int id) async {
    return await _db.reminders.get(id);
  }

  // ============================================================
  // REACTIVE STREAMS
  // ============================================================

  /// Watches all reminders and emits updated list on any change.
  Stream<List<Reminder>> watchAllReminders() {
    return _db.reminders.where().sortByHour().thenByMinute().watch(
      fireImmediately: true,
    );
  }

  /// Watches only enabled reminders.
  Stream<List<Reminder>> watchEnabledReminders() {
    return _db.reminders
        .filter()
        .enabledEqualTo(true)
        .sortByHour()
        .thenByMinute()
        .watch(fireImmediately: true);
  }
}
