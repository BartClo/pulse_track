import 'package:flutter/material.dart';
import '../widgets/period_filter_chips.dart';
import '../widgets/chart_summary_cards.dart';
import '../widgets/blood_pressure_chart.dart';
import '../widgets/pulse_chart.dart';
import '../../pressure_entry/widgets/reference_values_card.dart';
import '../../../models/dashboard_data.dart';
import '../../../data/repositories/pressure_repository.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  ChartPeriod _period = ChartPeriod.semana;

  // Stream must be recreated when period changes
  Stream<ChartData>? _chartStream;

  int get _periodDays {
    switch (_period) {
      case ChartPeriod.dia:
        return 1;
      case ChartPeriod.semana:
        return 7;
      case ChartPeriod.mes:
        return 30;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    _chartStream = PressureRepository.instance.watchChartData(_periodDays);
  }

  void _onPeriodChanged(ChartPeriod period) {
    setState(() {
      _period = period;
      _updateStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gráficos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: StreamBuilder<ChartData>(
        stream: _chartStream,
        builder: (context, snapshot) {
          // Error state
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Data state - use pre-computed ChartData
          final data = snapshot.data ?? ChartData.fromReadings([]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                PeriodFilterChips(
                  selected: _period,
                  onChanged: _onPeriodChanged,
                ),
                const SizedBox(height: 16),
                ChartSummaryCards(
                  averageValue: data.averageDisplay,
                  trend: data.trend,
                ),
                const SizedBox(height: 16),
                BloodPressureChart(readings: data.readings),
                const SizedBox(height: 16),
                PulseChart(readings: data.readings),
                const SizedBox(height: 16),
                const ReferenceValuesCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error al cargar gráficos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
