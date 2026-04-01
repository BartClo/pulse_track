import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'session_service.dart';

/// Service that wraps Supabase client operations.
///
/// Provides helper methods for database operations with error handling.
/// All cloud operations are non-blocking and fail gracefully.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient? _client;

  /// Initialize the Supabase service.
  void initialize() {
    if (SupabaseConfig.isConfigured) {
      _client = Supabase.instance.client;
    }
  }

  /// Whether Supabase is available.
  bool get isAvailable => _client != null && SupabaseConfig.isConfigured;

  /// Get the Supabase client (throws if not available).
  SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase not initialized');
    }
    return _client!;
  }

  /// Get current user ID if logged in.
  Future<String?> get currentUserId async {
    final session = await SessionService.instance.getSession();
    if (session == null || session.isGuest) return null;
    return session.userId;
  }

  /// Whether user is logged in (not guest).
  Future<bool> get isLoggedIn async {
    final session = await SessionService.instance.getSession();
    return session?.isLoggedIn ?? false;
  }

  // ============================================================
  // PROFILES TABLE
  // ============================================================

  /// Upsert profile to Supabase.
  Future<void> upsertProfile({
    required String userId,
    required String name,
    required int age,
    required double weight,
    required double height,
  }) async {
    if (!isAvailable) return;

    try {
      await client.from('profiles').upsert({
        'user_id': userId,
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logError('upsertProfile', e);
    }
  }

  /// Fetch profile from Supabase.
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (!isAvailable) return null;

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      _logError('fetchProfile', e);
      return null;
    }
  }

  // ============================================================
  // PRESSURE READINGS TABLE
  // ============================================================

  /// Insert a pressure reading to Supabase.
  /// Returns the remote ID if successful.
  Future<String?> insertReading({
    required String userId,
    required int localId,
    required int systolic,
    required int diastolic,
    required int pulse,
    required DateTime date,
  }) async {
    if (!isAvailable) return null;

    try {
      final response = await client
          .from('pressure_readings')
          .insert({
            'user_id': userId,
            'local_id': localId,
            'systolic': systolic,
            'diastolic': diastolic,
            'pulse': pulse,
            'date': date.toIso8601String(),
          })
          .select('id')
          .single();

      return response['id']?.toString();
    } catch (e) {
      _logError('insertReading', e);
      return null;
    }
  }

  /// Fetch readings from Supabase for a user.
  /// If [since] is provided, only fetches readings updated after that date.
  Future<List<Map<String, dynamic>>> fetchReadings(String userId, {DateTime? since}) async {
    if (!isAvailable) return [];

    try {
      var query = client
          .from('pressure_readings')
          .select()
          .eq('user_id', userId);
      
      // Incremental sync: only fetch records updated after lastSyncDate
      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }
      
      final response = await query.order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logError('fetchReadings', e);
      return [];
    }
  }

  /// Delete a reading from Supabase.
  Future<bool> deleteReading(String remoteId) async {
    if (!isAvailable) return false;

    try {
      await client.from('pressure_readings').delete().eq('id', remoteId);
      return true;
    } catch (e) {
      _logError('deleteReading', e);
      return false;
    }
  }

  /// Batch insert readings (for migration).
  Future<int> batchInsertReadings({
    required String userId,
    required List<Map<String, dynamic>> readings,
  }) async {
    if (!isAvailable || readings.isEmpty) return 0;

    try {
      final data = readings.map((r) => {...r, 'user_id': userId}).toList();

      await client
          .from('pressure_readings')
          .upsert(data, onConflict: 'user_id,local_id');
      return readings.length;
    } catch (e) {
      _logError('batchInsertReadings', e);
      return 0;
    }
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  void _logError(String operation, Object error) {
    // In production, use a proper logging service
    print('[SupabaseService] $operation failed: $error');
  }
}
