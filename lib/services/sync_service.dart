import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/local_db.dart';
import '../models/pressure_reading.dart';
import '../models/user_profile.dart';
import 'session_service.dart';
import 'supabase_service.dart';

/// Service that handles bidirectional sync between Isar and Supabase.
///
/// Supports:
/// - Incremental sync (only fetch updated data)
/// - Sync from cloud on app start
/// - Push local changes to cloud
/// - Migration from guest to logged-in user
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  Isar get _db => LocalDatabase.instance;
  SupabaseService get _supabase => SupabaseService.instance;
  SessionService get _session => SessionService.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncDate;

  static const String _lastSyncKey = 'last_sync_date';
  static const String _lastProfileSyncKey = 'last_profile_sync_date';

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Last sync date (for UI display).
  DateTime? get lastSyncDate => _lastSyncDate;

  /// Load last sync date from SharedPreferences.
  Future<void> _loadLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    if (timestamp != null) {
      _lastSyncDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  /// Save last sync date to SharedPreferences.
  Future<void> _saveLastSyncDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, date.millisecondsSinceEpoch);
    _lastSyncDate = date;
  }

  /// Get formatted last sync time for UI display.
  String get lastSyncFormatted {
    if (_lastSyncDate == null) return 'Nunca';
    
    final now = DateTime.now();
    final diff = now.difference(_lastSyncDate!);
    
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }

  // ============================================================
  // FULL SYNC
  // ============================================================

  /// Performs incremental sync from cloud to local.
  /// Only fetches data updated since last sync.
  /// Call this on app start if user is logged in.
  Future<void> syncFromCloud({bool forceFullSync = false}) async {
    if (_isSyncing) return;

    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) return;

    _isSyncing = true;

    try {
      // Load last sync date
      await _loadLastSyncDate();
      
      final userId = session.userId!;
      final syncSince = forceFullSync ? null : _lastSyncDate;

      // Sync profile
      await _syncProfileFromCloud(userId);

      // Sync readings (incremental)
      await _syncReadingsFromCloud(userId, since: syncSince);

      // Update last sync date
      await _saveLastSyncDate(DateTime.now());
      
      _log('Sync completed at ${DateTime.now()}');
    } catch (e) {
      _logError('syncFromCloud', e);
    } finally {
      _isSyncing = false;
    }
  }

  /// Check if profile exists in cloud and load it.
  /// Returns true if profile was found and loaded, false otherwise.
  Future<bool> checkAndLoadProfileFromCloud() async {
    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) {
      return false;
    }

    try {
      final userId = session.userId!;
      final remoteProfile = await _supabase.fetchProfile(userId);

      if (remoteProfile == null) {
        return false;
      }

      // Profile exists in cloud, save to local
      final cloudProfile = UserProfile.fromSupabase(remoteProfile);
      await _db.writeTxn(() async {
        cloudProfile.id = UserProfile.singletonId;
        await _db.userProfiles.put(cloudProfile);
      });

      _log('Profile loaded from cloud for user: $userId');
      return true;
    } catch (e) {
      _logError('checkAndLoadProfileFromCloud', e);
      return false;
    }
  }

  /// Sync profile from cloud.
  Future<void> _syncProfileFromCloud(String userId) async {
    final remoteProfile = await _supabase.fetchProfile(userId);
    if (remoteProfile == null) return;

    final localProfile = await _db.userProfiles.get(UserProfile.singletonId);
    final cloudProfile = UserProfile.fromSupabase(remoteProfile);

    // If no local profile or cloud is newer, update local
    if (localProfile == null) {
      await _db.writeTxn(() async {
        cloudProfile.id = UserProfile.singletonId;
        await _db.userProfiles.put(cloudProfile);
      });
    } else if (!localProfile.isSynced) {
      // Local has unsynced changes, push to cloud instead
      await _pushProfileToCloud(localProfile, userId);
    }
  }

  /// Sync readings from cloud.
  /// Fetches readings from Supabase (optionally since a date) and stores them in Isar.
  /// Avoids duplicates by checking remoteId or matching date+values.
  Future<void> _syncReadingsFromCloud(String userId, {DateTime? since}) async {
    final remoteReadings = await _supabase.fetchReadings(userId, since: since);
    if (remoteReadings.isEmpty) {
      _log('No new readings to sync');
      return;
    }

    _log('Syncing ${remoteReadings.length} readings from cloud${since != null ? ' (incremental)' : ' (full)'}');

    await _db.writeTxn(() async {
      for (final remote in remoteReadings) {
        final remoteId = remote['id']?.toString();
        final localId = remote['local_id'] as int?;

        // Strategy 1: Check by local_id if available
        PressureReading? existing;
        if (localId != null) {
          existing = await _db.pressureReadings.get(localId);
        }

        // Strategy 2: Check by remoteId
        if (existing == null && remoteId != null) {
          existing = await _db.pressureReadings
              .filter()
              .remoteIdEqualTo(remoteId)
              .findFirst();
        }

        // Strategy 3: Check by date + values (avoid exact duplicates)
        if (existing == null) {
          final date = DateTime.parse(remote['date'] as String);
          final systolic = remote['systolic'] as int;
          final diastolic = remote['diastolic'] as int;
          final pulse = remote['pulse'] as int;

          existing = await _db.pressureReadings
              .filter()
              .dateEqualTo(date)
              .and()
              .systolicEqualTo(systolic)
              .and()
              .diastolicEqualTo(diastolic)
              .and()
              .pulseEqualTo(pulse)
              .findFirst();
        }

        if (existing == null) {
          // New reading from cloud, insert locally
          final reading = PressureReading.fromSupabase(remote);
          await _db.pressureReadings.put(reading);
        } else if (existing.remoteId == null) {
          // Local reading exists but not linked to cloud
          existing.remoteId = remoteId;
          existing.userId = userId;
          existing.isSynced = true;
          await _db.pressureReadings.put(existing);
        }
      }
    });

    _log('Readings sync completed');
  }

  /// Public method to sync readings from cloud.
  /// Call this after login or on app start if logged in.
  Future<void> syncReadingsFromCloud({bool incremental = true}) async {
    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) return;

    try {
      await _loadLastSyncDate();
      final since = incremental ? _lastSyncDate : null;
      await _syncReadingsFromCloud(session.userId!, since: since);
      await _saveLastSyncDate(DateTime.now());
    } catch (e) {
      _logError('syncReadingsFromCloud', e);
    }
  }

  // ============================================================
  // PUSH TO CLOUD
  // ============================================================

  /// Push a single reading to cloud (non-blocking).
  Future<void> pushReadingToCloud(PressureReading reading) async {
    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) return;

    final userId = session.userId!;

    try {
      final remoteId = await _supabase.insertReading(
        userId: userId,
        localId: reading.id,
        systolic: reading.systolic,
        diastolic: reading.diastolic,
        pulse: reading.pulse,
        date: reading.date,
      );

      if (remoteId != null) {
        // Update local record with remote ID
        await _db.writeTxn(() async {
          reading.remoteId = remoteId;
          reading.userId = userId;
          reading.isSynced = true;
          await _db.pressureReadings.put(reading);
        });
      }
    } catch (e) {
      _logError('pushReadingToCloud', e);
    }
  }

  /// Push profile to cloud.
  Future<void> _pushProfileToCloud(UserProfile profile, String userId) async {
    try {
      await _supabase.upsertProfile(
        userId: userId,
        name: profile.name,
        age: profile.age,
        weight: profile.weight,
        height: profile.height,
      );

      // Mark as synced
      await _db.writeTxn(() async {
        profile.userId = userId;
        profile.isSynced = true;
        await _db.userProfiles.put(profile);
      });
    } catch (e) {
      _logError('_pushProfileToCloud', e);
    }
  }

  /// Push current profile to cloud (public API).
  Future<void> pushProfileToCloud() async {
    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) return;

    final profile = await _db.userProfiles.get(UserProfile.singletonId);
    if (profile == null) return;

    await _pushProfileToCloud(profile, session.userId!);
  }

  // ============================================================
  // GUEST MIGRATION
  // ============================================================

  /// Migrate all local data to cloud when guest logs in.
  /// Call this after successful Google login.
  Future<void> migrateGuestData() async {
    final session = await _session.getSession();
    if (session == null || session.isGuest || session.userId == null) return;

    final userId = session.userId!;

    try {
      // Migrate profile
      final profile = await _db.userProfiles.get(UserProfile.singletonId);
      if (profile != null && !profile.isSynced) {
        await _pushProfileToCloud(profile, userId);
      }

      // Migrate unsynced readings
      final unsyncedReadings = await _db.pressureReadings
          .filter()
          .isSyncedEqualTo(false)
          .findAll();

      if (unsyncedReadings.isEmpty) return;

      // Batch upload
      final readingsData = unsyncedReadings.map((r) => r.toSupabase()).toList();
      final count = await _supabase.batchInsertReadings(
        userId: userId,
        readings: readingsData,
      );

      if (count > 0) {
        // Mark all as synced
        await _db.writeTxn(() async {
          for (final reading in unsyncedReadings) {
            reading.userId = userId;
            reading.isSynced = true;
            await _db.pressureReadings.put(reading);
          }
        });
      }

      _log('Migrated $count readings to cloud');
    } catch (e) {
      _logError('migrateGuestData', e);
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  void _log(String message) {
    print('[SyncService] $message');
  }

  void _logError(String operation, Object error) {
    print('[SyncService] $operation failed: $error');
  }
}
