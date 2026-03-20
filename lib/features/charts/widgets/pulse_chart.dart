import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/pressure_reading.dart';

class PulseChart extends StatelessWidget {
  final List<PressureReading> readings;

  const PulseChart({super.key, required this.readings});

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
            'Pulso cardíaco',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: readings.length < 2
                ? _buildEmptyState()
                : LineChart(_buildChartData()),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 2.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Pulso (bpm)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
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

    final spots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].pulse.toDouble()));
    }

    final minPulse = sorted.map((r) => r.pulse).reduce((a, b) => a < b ? a : b);
    final maxPulse = sorted.map((r) => r.pulse).reduce((a, b) => a > b ? a : b);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 10,
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
            interval: 10,
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
      minY: ((minPulse - 10) / 10).floor() * 10.0,
      maxY: ((maxPulse + 10) / 10).ceil() * 10.0,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: const Color(0xFF4CAF50),
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: const Color(0xFF4CAF50),
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((spot) {
            return LineTooltipItem(
              '${spot.y.toInt()} bpm',
              const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ),
    );
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
