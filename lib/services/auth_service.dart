import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/session_data.dart';
import 'session_service.dart';
import 'sync_service.dart';

/// Service that handles authentication operations.
///
/// Supports:
/// - Google OAuth via Supabase
/// - Guest mode (local only)
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient? _supabase;

  /// Initialize the auth service.
  /// Must be called after Supabase.initialize().
  void initialize() {
    if (SupabaseConfig.isConfigured) {
      _supabase = Supabase.instance.client;
      _setupAuthListener();
    }
  }

  /// Whether Supabase is available for cloud auth.
  bool get isSupabaseAvailable =>
      _supabase != null && SupabaseConfig.isConfigured;

  /// Callback when login completes successfully.
  /// Parameters: (bool hasProfile) - true if profile exists in cloud
  static void Function(bool hasProfile)? onLoginComplete;

  /// Sets up listener for auth state changes from Supabase.
  void _setupAuthListener() {
    _supabase?.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        await _saveSupabaseSession(session);
        // Check if profile exists in cloud
        await _checkProfileAndNotify();
      } else if (event == AuthChangeEvent.signedOut) {
        await SessionService.instance.clearSession();
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        await _saveSupabaseSession(session);
      }
    });
  }

  /// Check if profile exists in cloud and notify via callback.
  /// Also syncs readings from cloud after profile check.
  Future<void> _checkProfileAndNotify() async {
    try {
      final hasProfile = await SyncService.instance.checkAndLoadProfileFromCloud();
      
      // Also sync readings from cloud (non-blocking for UI)
      SyncService.instance.syncReadingsFromCloud().catchError((e) {
        // Silently handle - readings sync is not critical for login flow
      });
      
      onLoginComplete?.call(hasProfile);
    } catch (e) {
      onLoginComplete?.call(false);
    }
  }

  /// Saves Supabase session to local storage.
  Future<void> _saveSupabaseSession(Session session) async {
    final sessionData = SessionData(
      isGuest: false,
      userId: session.user.id,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : null,
    );
    await SessionService.instance.saveSession(sessionData);
  }

  /// Signs in with Google OAuth via Supabase.
  ///
  /// Returns true if sign-in was initiated successfully.
  /// The actual session will be saved when the OAuth callback completes.
  Future<bool> signInWithGoogle() async {
    if (!isSupabaseAvailable) {
      throw StateError(
        'Supabase not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    try {
      await _supabase!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.pulsetrack://login-callback/',
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs out the current user.
  ///
  /// Clears both Supabase session and local session.
  Future<void> signOut() async {
    try {
      if (isSupabaseAvailable) {
        await _supabase!.auth.signOut();
      }
    } finally {
      await SessionService.instance.clearSession();
    }
  }

  /// Continues as guest (local-only mode).
  ///
  /// Sets up a guest session that allows full app usage
  /// without cloud sync capabilities.
  Future<void> continueAsGuest() async {
    await SessionService.instance.setGuestMode();
  }

  /// Gets the current Supabase user, if logged in.
  User? get currentUser => _supabase?.auth.currentUser;

  /// Refreshes the current session tokens.
  Future<void> refreshSession() async {
    if (!isSupabaseAvailable) return;

    final response = await _supabase!.auth.refreshSession();
    if (response.session != null) {
      await _saveSupabaseSession(response.session!);
    }
  }

  /// Restores session from Supabase on app startup.
  Future<void> restoreSession() async {
    if (!isSupabaseAvailable) return;

    final session = _supabase!.auth.currentSession;
    if (session != null) {
      await _saveSupabaseSession(session);
    }
  }
}
