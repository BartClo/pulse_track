import 'dart:convert';
import 'package:isar/isar.dart';

part 'pressure_reading.g.dart';

@collection
class PressureReading {
  Id id = Isar.autoIncrement;

  final int systolic;
  final int diastolic;
  final int pulse;

  @Index()
  final DateTime date;

  PressureReading({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.date,
  });

  /// Classification based on blood pressure values.
  @ignore
  String get status {
    if (systolic >= 140 || diastolic >= 90) return 'Alta';
    if (systolic >= 130 || diastolic >= 85) return 'Elevada';
    return 'Normal';
  }

  /// Returns a color hex value for the status (green/amber/red).
  @ignore
  int get statusColorValue {
    switch (status) {
      case 'Alta':
        return 0xFFF44336;
      case 'Elevada':
        return 0xFFFFA000;
      default:
        return 0xFF4CAF50;
    }
  }

  /// Formatted date string like "Hoy, 08:30" or "17/03, 14:20".
  @ignore
  String get formattedDate {
    final now = DateTime.now();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy, $time';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Ayer, $time';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month, $time';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'date': date.toIso8601String(),
  };

  factory PressureReading.fromJson(Map<String, dynamic> json) {
    return PressureReading(
      systolic: json['systolic'] as int,
      diastolic: json['diastolic'] as int,
      pulse: json['pulse'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }

  /// Encode a list of readings to a JSON string.
  static String encodeList(List<PressureReading> readings) {
    return jsonEncode(readings.map((r) => r.toJson()).toList());
  }

  /// Decode a JSON string into a list of readings.
  static List<PressureReading> decodeList(String jsonString) {
    final List<dynamic> data = jsonDecode(jsonString) as List<dynamic>;
    return data
        .map((e) => PressureReading.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
