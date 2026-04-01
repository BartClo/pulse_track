import 'package:isar/isar.dart';
import '../models/session_data.dart';
import '../data/datasources/local_db.dart';

/// Service that manages user session state.
///
/// Handles session persistence using Isar and provides
/// reactive updates via streams.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  Isar get _db => LocalDatabase.instance;

  static const int _sessionId = SessionData.singletonId;

  SessionData? _cachedSession;

  /// Returns the current session data, if any.
  Future<SessionData?> getSession() async {
    _cachedSession = await _db.sessionDatas.get(_sessionId);
    return _cachedSession;
  }

  /// Watches session changes and emits updates automatically.
  Stream<SessionData?> watchSession() {
    return _db.sessionDatas.watchObject(_sessionId, fireImmediately: true);
  }

  /// Whether the user is currently logged in (not guest, has valid userId).
  Future<bool> get isLoggedIn async {
    final session = await getSession();
    return session?.isLoggedIn ?? false;
  }

  /// Whether the user is in guest mode.
  Future<bool> get isGuest async {
    final session = await getSession();
    return session?.isGuest ?? false;
  }

  /// The current user ID, if logged in.
  Future<String?> get userId async {
    final session = await getSession();
    return session?.userId;
  }

  /// Whether any session exists (logged in or guest).
  Future<bool> get hasSession async {
    final session = await getSession();
    if (session == null) return false;
    return session.isGuest || session.isLoggedIn;
  }

  /// Saves a new session (from Supabase auth or guest mode).
  Future<void> saveSession(SessionData session) async {
    await _db.writeTxn(() async {
      session.id = _sessionId;
      await _db.sessionDatas.put(session);
    });
    _cachedSession = session;
  }

  /// Updates the current session.
  Future<void> updateSession(SessionData session) async {
    await _db.writeTxn(() async {
      session.id = _sessionId;
      await _db.sessionDatas.put(session);
    });
    _cachedSession = session;
  }

  /// Clears the current session (logout).
  Future<void> clearSession() async {
    await _db.writeTxn(() async {
      await _db.sessionDatas.delete(_sessionId);
    });
    _cachedSession = null;
  }

  /// Sets guest mode session.
  Future<void> setGuestMode() async {
    final session = SessionData(isGuest: true);
    await saveSession(session);
  }

  /// Updates tokens after refresh.
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    final current = await getSession();
    if (current == null) return;

    final updated = current.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
    await updateSession(updated);
  }
}
