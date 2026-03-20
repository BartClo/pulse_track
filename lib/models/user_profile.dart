import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
  });

  static const int singletonId = 1;

  Id id = singletonId;

  String name;
  int age;
  double weight;
  double height;

  @ignore
  String get formattedWeight =>
      weight == weight.roundToDouble() ? '${weight.toInt()} kg' : '${weight.toStringAsFixed(1)} kg';

  @ignore
  String get formattedHeight =>
      height == height.roundToDouble() ? '${height.toInt()} cm' : '${height.toStringAsFixed(1)} cm';

  @ignore
  String get formattedAge => '$age años';

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
    )..id = id;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
    )..id = (map['id'] as int?) ?? singletonId;
  }
}
