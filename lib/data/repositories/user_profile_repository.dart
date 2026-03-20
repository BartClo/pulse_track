import 'package:isar/isar.dart';
import '../../models/user_profile.dart';
import '../datasources/local_db.dart';

/// Repository that manages the single user profile stored in Isar.
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
  Future<void> saveProfile(UserProfile profile) async {
    await _db.writeTxn(() async {
      final exists = await _db.userProfiles.get(_profileId);
      if (exists != null) {
        throw StateError('El perfil ya existe. Usa updateProfile para modificarlo.');
      }

      profile.id = _profileId;
      await _db.userProfiles.put(profile);
    });
  }

  /// Updates the profile, creating it if it doesn't exist.
  Future<void> updateProfile(UserProfile profile) async {
    await _db.writeTxn(() async {
      profile.id = _profileId;
      await _db.userProfiles.put(profile);
    });
  }

  /// Ensures there is always a profile available for other modules.
  Future<UserProfile> ensureProfile({
    UserProfile? fallback,
  }) async {
    final current = await getProfile();
    if (current != null) return current;

    final defaultProfile = fallback ??
        UserProfile(
          name: 'Usuario',
          age: 45,
          weight: 75,
          height: 170,
        );

    await saveProfile(defaultProfile);
    return defaultProfile;
  }
}
