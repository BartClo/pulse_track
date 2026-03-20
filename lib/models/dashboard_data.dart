import 'pressure_reading.dart';

/// Derived data model for the Dashboard screen.
/// Pre-computed values ready for UI consumption.
class DashboardData {
  final PressureReading? latestReading;
  final String averageDisplay;
  final int todayCount;
  final List<PressureReading> weeklyReadings;

  const DashboardData({
    required this.latestReading,
    required this.averageDisplay,
    required this.todayCount,
    required this.weeklyReadings,
  });

  /// Factory to create DashboardData from raw readings list.
  factory DashboardData.fromReadings(List<PressureReading> readings) {
    final now = DateTime.now();

    // Latest reading (already sorted by date DESC)
    final latest = readings.isNotEmpty ? readings.first : null;

    // Today's count
    final todayCount = readings
        .where(
          (r) =>
              r.date.year == now.year &&
              r.date.month == now.month &&
              r.date.day == now.day,
        )
        .length;

    // Weekly average
    String averageDisplay = '---/---';
    if (readings.isNotEmpty) {
      final avgSys =
          readings.map((r) => r.systolic).reduce((a, b) => a + b) ~/
          readings.length;
      final avgDia =
          readings.map((r) => r.diastolic).reduce((a, b) => a + b) ~/
          readings.length;
      averageDisplay = '$avgSys/$avgDia';
    }

    return DashboardData(
      latestReading: latest,
      averageDisplay: averageDisplay,
      todayCount: todayCount,
      weeklyReadings: readings,
    );
  }

  /// Formatted string for today's count.
  String get todayDisplay =>
      '$todayCount ${todayCount == 1 ? 'medición' : 'mediciones'}';

  /// Empty state check.
  bool get isEmpty => latestReading == null;
}

/// Derived data model for the History screen.
class HistoryData {
  final List<PressureReading> allReadings;
  final Map<String, int> statusCounts;
  final Map<DateTime, List<PressureReading>> groupedByDate;
  final List<DateTime> sortedDates;

  const HistoryData({
    required this.allReadings,
    required this.statusCounts,
    required this.groupedByDate,
    required this.sortedDates,
  });

  /// Factory to create HistoryData from raw readings list.
  factory HistoryData.fromReadings(List<PressureReading> readings) {
    // Status counts
    final counts = {
      'Todas': readings.length,
      'Normal': readings.where((r) => r.status == 'Normal').length,
      'Elevada': readings.where((r) => r.status == 'Elevada').length,
      'Alta': readings.where((r) => r.status == 'Alta').length,
    };

    // Group by date
    final grouped = <DateTime, List<PressureReading>>{};
    for (final reading in readings) {
      final key = DateTime(
        reading.date.year,
        reading.date.month,
        reading.date.day,
      );
      grouped.putIfAbsent(key, () => []).add(reading);
    }

    // Sorted dates (newest first)
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return HistoryData(
      allReadings: readings,
      statusCounts: counts,
      groupedByDate: grouped,
      sortedDates: sortedDates,
    );
  }

  /// Filter readings by status and return new grouped data.
  HistoryData filterByStatus(String status) {
    if (status == 'Todas') return this;

    final filtered = allReadings.where((r) => r.status == status).toList();

    // Regroup filtered readings
    final grouped = <DateTime, List<PressureReading>>{};
    for (final reading in filtered) {
      final key = DateTime(
        reading.date.year,
        reading.date.month,
        reading.date.day,
      );
      grouped.putIfAbsent(key, () => []).add(reading);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return HistoryData(
      allReadings: allReadings, // Keep original for counts
      statusCounts: statusCounts, // Keep original counts
      groupedByDate: grouped,
      sortedDates: sortedDates,
    );
  }

  bool get isEmpty => allReadings.isEmpty;
}

/// Derived data model for the Charts screen.
class ChartData {
  final List<PressureReading> readings;
  final String averageDisplay;
  final int? trend;

  const ChartData({
    required this.readings,
    required this.averageDisplay,
    required this.trend,
  });

  /// Factory to create ChartData from raw readings list.
  factory ChartData.fromReadings(List<PressureReading> readings) {
    // Calculate average
    String averageDisplay = '---/---';
    if (readings.isNotEmpty) {
      final avgSys =
          readings.map((r) => r.systolic).reduce((a, b) => a + b) ~/
          readings.length;
      final avgDia =
          readings.map((r) => r.diastolic).reduce((a, b) => a + b) ~/
          readings.length;
      averageDisplay = '$avgSys/$avgDia';
    }

    // Calculate trend
    int? trend;
    if (readings.length >= 2) {
      final sorted = List<PressureReading>.from(readings)
        ..sort((a, b) => a.date.compareTo(b.date));

      final half = sorted.length ~/ 2;
      final firstHalf = sorted.sublist(0, half);
      final secondHalf = sorted.sublist(half);

      final avgFirst =
          firstHalf.map((r) => r.systolic).reduce((a, b) => a + b) ~/
          firstHalf.length;
      final avgSecond =
          secondHalf.map((r) => r.systolic).reduce((a, b) => a + b) ~/
          secondHalf.length;

      trend = avgSecond - avgFirst;
    }

    return ChartData(
      readings: readings,
      averageDisplay: averageDisplay,
      trend: trend,
    );
  }

  bool get isEmpty => readings.isEmpty;
}
