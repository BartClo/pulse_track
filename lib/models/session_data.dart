import 'package:isar/isar.dart';

part 'session_data.g.dart';

@collection
class SessionData {
  SessionData({
    this.isGuest = false,
    this.userId,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  static const int singletonId = 1;

  Id id = singletonId;

  bool isGuest;
  String? userId;
  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;

  @ignore
  bool get isLoggedIn => !isGuest && userId != null && accessToken != null;

  @ignore
  bool get isTokenExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  SessionData copyWith({
    bool? isGuest,
    String? userId,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return SessionData(
      isGuest: isGuest ?? this.isGuest,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    )..id = id;
  }

  void clear() {
    isGuest = false;
    userId = null;
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
  }
}
