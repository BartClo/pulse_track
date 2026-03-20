import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/pressure_reading.dart';
import '../../models/reminder.dart';
import '../../models/user_profile.dart';

/// Singleton class that manages the Isar database instance.
///
/// Initialize once at app startup using [LocalDatabase.initialize()].
/// Access the database instance via [LocalDatabase.instance].
class LocalDatabase {
  LocalDatabase._();

  static Isar? _isar;

  /// Returns the Isar database instance.
  /// Throws if [initialize] hasn't been called.
  static Isar get instance {
    if (_isar == null) {
      throw StateError(
        'LocalDatabase not initialized. Call LocalDatabase.initialize() first.',
      );
    }
    return _isar!;
  }

  /// Indicates whether the database has been initialized.
  static bool get isInitialized => _isar != null;

  /// Initializes the Isar database.
  ///
  /// Must be called once before accessing [instance].
  /// Typically called in main() before runApp().
  static Future<Isar> initialize() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [PressureReadingSchema, ReminderSchema, UserProfileSchema],
      directory: dir.path,
      name: 'pulse_track_db',
    );

    return _isar!;
  }

  /// Closes the database connection.
  ///
  /// Only needed for testing or special scenarios.
  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
