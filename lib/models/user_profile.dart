import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.userId,
    this.isSynced = false,
  });

  static const int singletonId = 1;

  Id id = singletonId;

  String name;
  int age;
  double weight;
  double height;

  /// User ID for cloud sync (null for guest).
  String? userId;

  /// Whether this profile has been synced to cloud.
  bool isSynced;

  @ignore
  String get formattedWeight => weight == weight.roundToDouble()
      ? '${weight.toInt()} kg'
      : '${weight.toStringAsFixed(1)} kg';

  @ignore
  String get formattedHeight => height == height.roundToDouble()
      ? '${height.toInt()} cm'
      : '${height.toStringAsFixed(1)} cm';

  @ignore
  String get formattedAge => '$age años';

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? userId,
    bool? isSynced,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    )..id = id;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'weight': weight,
    'height': height,
    'user_id': userId,
    'is_synced': isSynced,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
      userId: map['user_id'] as String?,
      isSynced: map['is_synced'] as bool? ?? false,
    )..id = (map['id'] as int?) ?? singletonId;
  }

  /// Create from Supabase response.
  factory UserProfile.fromSupabase(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
      userId: map['user_id'] as String?,
      isSynced: true,
    );
  }
}
