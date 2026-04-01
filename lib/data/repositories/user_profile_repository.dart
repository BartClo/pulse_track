import 'package:isar/isar.dart';
import '../../models/user_profile.dart';
import '../datasources/local_db.dart';
import '../../services/sync_service.dart';

/// Repository that manages the single user profile stored in Isar.
/// Automatically syncs to cloud when user is logged in.
class UserProfileRepository {
  UserProfileRepository._();

  static final UserProfileRepository instance = UserProfileRepository._();

  Isar get _db => LocalDatabase.instance;

  static const int _profileId = UserProfile.singletonId;

  /// Watches the profile and emits updates automatically.
  Stream<UserProfile?> watchProfile() {
    return _db.userProfiles.watchObject(_profileId, fireImmediately: true);
  }

  /// Returns the stored profile, if any.
  Future<UserProfile?> getProfile() {
    return _db.userProfiles.get(_profileId);
  }

  /// Saves the profile if none exists yet.
  /// Syncs to cloud if user is logged in.
  Future<void> saveProfile(UserProfile profile) async {
    await _db.writeTxn(() async {
      final exists = await _db.userProfiles.get(_profileId);
      if (exists != null) {
        throw StateError(
          'El perfil ya existe. Usa updateProfile para modificarlo.',
        );
      }

      profile.id = _profileId;
      await _db.userProfiles.put(profile);
    });

    // Sync to cloud (non-blocking)
    _syncToCloud();
  }

  /// Updates the profile, creating it if it doesn't exist.
  /// Syncs to cloud if user is logged in.
  Future<void> updateProfile(UserProfile profile) async {
    await _db.writeTxn(() async {
      profile.id = _profileId;
      await _db.userProfiles.put(profile);
    });

    // Sync to cloud (non-blocking)
    _syncToCloud();
  }

  /// Syncs profile to cloud without blocking UI.
  void _syncToCloud() {
    // Fire and forget
    SyncService.instance.pushProfileToCloud().catchError((e) {
      print('[UserProfileRepository] Cloud sync failed: $e');
    });
  }

  /// Ensures there is always a profile available for other modules.
  Future<UserProfile> ensureProfile({UserProfile? fallback}) async {
    final current = await getProfile();
    if (current != null) return current;

    final defaultProfile =
        fallback ??
        UserProfile(name: 'Usuario', age: 45, weight: 75, height: 170);

    await saveProfile(defaultProfile);
    return defaultProfile;
  }
}
