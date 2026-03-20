import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/pressure_reading.dart';

class BloodPressureChart extends StatelessWidget {
  final List<PressureReading> readings;

  const BloodPressureChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Presión arterial',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: readings.length < 2
                ? _buildEmptyState()
                : LineChart(_buildChartData()),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: const Color(0xFFF44336), label: 'Sistólica'),
              const SizedBox(width: 24),
              _LegendItem(color: const Color(0xFF2979FF), label: 'Diastólica'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Se necesitan al menos 2 mediciones',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
      ),
    );
  }

  LineChartData _buildChartData() {
    final sorted = List<PressureReading>.from(readings)
      ..sort((a, b) => a.date.compareTo(b.date));

    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];

    for (var i = 0; i < sorted.length; i++) {
      sysSpots.add(FlSpot(i.toDouble(), sorted[i].systolic.toDouble()));
      diaSpots.add(FlSpot(i.toDouble(), sorted[i].diastolic.toDouble()));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 20,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= sorted.length) {
                return const SizedBox.shrink();
              }
              final d = sorted[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${d.day} ${_shortMonth(d.month)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: _minY(sorted),
      maxY: _maxY(sorted),
      lineBarsData: [
        _buildLine(sysSpots, const Color(0xFFF44336)),
        _buildLine(diaSpots, const Color(0xFF2979FF)),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((spot) {
            return LineTooltipItem(
              spot.y.toInt().toString(),
              TextStyle(
                color: spot.bar.color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeWidth: 2.5,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _minY(List<PressureReading> sorted) {
    final minDia = sorted
        .map((r) => r.diastolic)
        .reduce((a, b) => a < b ? a : b);
    return ((minDia - 10) / 10).floor() * 10.0;
  }

  double _maxY(List<PressureReading> sorted) {
    final maxSys = sorted
        .map((r) => r.systolic)
        .reduce((a, b) => a > b ? a : b);
    return ((maxSys + 10) / 10).ceil() * 10.0;
  }

  static String _shortMonth(int month) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[month - 1];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
