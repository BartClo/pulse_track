import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/history_filter_chips.dart';
import '../widgets/date_section_header.dart';
import '../widgets/history_reading_card.dart';
import '../../../models/dashboard_data.dart';
import '../../../data/repositories/pressure_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../models/user_profile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Stream initialized once in initState
  late final Stream<HistoryData> _historyStream;
  String _selectedFilter = 'Todas';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _historyStream = PressureRepository.instance.watchHistoryData();
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    
    setState(() => _isExporting = true);
    
    try {
      final readings = await PressureRepository.instance.getAllReadings();

      if (readings.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No hay datos para exportar'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      
      // Build CSV content with user profile metadata
      final buffer = StringBuffer();
      final UserProfile? profile = await UserProfileRepository.instance.getProfile();
      if (profile != null) {
        buffer.writeln('# Usuario: ${profile.name}');
        buffer.writeln('# Edad: ${profile.age}  Peso: ${profile.weight}kg  Altura: ${profile.height}cm');
        buffer.writeln('');
      }
      buffer.writeln('Fecha,Hora,Sistólica,Diastólica,Pulso,Estado');
      
      for (final reading in readings) {
        final date = '${reading.date.day.toString().padLeft(2, '0')}/${reading.date.month.toString().padLeft(2, '0')}/${reading.date.year}';
        final time = '${reading.date.hour.toString().padLeft(2, '0')}:${reading.date.minute.toString().padLeft(2, '0')}';
        final status = _getStatus(reading.systolic, reading.diastolic);
        buffer.writeln('$date,$time,${reading.systolic},${reading.diastolic},${reading.pulse},$status');
      }
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/pulsetrack_export_$timestamp.csv');
      await file.writeAsString(buffer.toString());
      
      if (!mounted) return;
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'PulseTrack - Historial de Presión Arterial',
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
  
  String _getStatus(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if (systolic < 130 && diastolic < 80) return 'Elevada';
    if (systolic < 140 || diastolic < 90) return 'HTA Etapa 1';
    if (systolic >= 140 || diastolic >= 90) return 'HTA Etapa 2';
    return 'Desconocido';
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
          'Historial',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Color(0xFF1A1A2E)),
            onPressed: _exportData,
          ),
        ],
      ),
      body: StreamBuilder<HistoryData>(
        stream: _historyStream,
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

          final rawData = snapshot.data ?? HistoryData.fromReadings([]);

          // Empty state
          if (rawData.isEmpty) {
            return _buildEmptyState();
          }

          // Apply filter using derived model method
          final data = rawData.filterByStatus(_selectedFilter);

          return Column(
            children: [
              // Filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: HistoryFilterChips(
                  selectedFilter: _selectedFilter,
                  counts: data.statusCounts,
                  onFilterChanged: (filter) {
                    setState(() => _selectedFilter = filter);
                  },
                ),
              ),
              // Readings list
              Expanded(
                child: data.sortedDates.isEmpty
                    ? _buildNoResultsState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.sortedDates.length,
                        itemBuilder: (context, index) {
                          final date = data.sortedDates[index];
                          final readings = data.groupedByDate[date]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DateSectionHeader(date: date),
                              ...readings.map(
                                (r) => HistoryReadingCard(reading: r),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Sin mediciones aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las mediciones guardadas aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Sin resultados para "$_selectedFilter"',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
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
              'Error al cargar historial',
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
