import 'package:flutter/material.dart';
import '../../../data/repositories/pressure_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../models/dashboard_data.dart';
import '../../../services/export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/history_filter_chips.dart';
import '../widgets/date_section_header.dart';
import '../widgets/history_reading_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Stream<HistoryData> _historyStream;
  String _selectedFilter = 'Todas';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _historyStream = PressureRepository.instance.watchHistoryData();
  }

  Future<ExportFormat?> _selectExportFormat() {
    return showModalBottomSheet<ExportFormat>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Exportar datos',
                  style: AppTextStyles.h4,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.table_chart_rounded, color: AppColors.success),
                  ),
                  title: Text('CSV', style: AppTextStyles.labelLarge),
                  subtitle: Text('Hoja de cálculo', style: AppTextStyles.caption),
                  onTap: () => Navigator.of(context).pop(ExportFormat.csv),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                  ),
                  title: Text('PDF', style: AppTextStyles.labelLarge),
                  subtitle: Text('Documento portable', style: AppTextStyles.caption),
                  onTap: () => Navigator.of(context).pop(ExportFormat.pdf),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportData() async {
    if (_isExporting) return;

    final format = await _selectExportFormat();
    if (format == null) return;

    setState(() => _isExporting = true);

    try {
      final readings = await PressureRepository.instance.getAllReadings();

      if (readings.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No hay datos para exportar'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final profile = await UserProfileRepository.instance.ensureProfile();
      final exportService = ExportService.instance;
      final filePath = format == ExportFormat.pdf
          ? await exportService.exportToPdf(readings, profile)
          : await exportService.exportToCsv(readings, profile);
      await exportService.shareFile(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Archivo exportado correctamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Historial',
          style: AppTextStyles.h4,
        ),
        actions: [
          if (_isExporting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                ),
                onPressed: _exportData,
              ),
            ),
        ],
      ),
      body: StreamBuilder<HistoryData>(
        stream: _historyStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            );
          }

          final rawData = snapshot.data ?? HistoryData.fromReadings([]);

          if (rawData.isEmpty) {
            return _buildEmptyState();
          }

          final data = rawData.filterByStatus(_selectedFilter);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: data.sortedDates.length,
                        itemBuilder: (context, dateIndex) {
                          final date = data.sortedDates[dateIndex];
                          final readings = data.groupedByDate[date]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DateSectionHeader(date: date),
                              ...readings.asMap().entries.map(
                                (entry) => HistoryReadingCard(
                                  reading: entry.value,
                                  index: entry.key,
                                ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin mediciones aún',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              'Las mediciones guardadas aparecerán aquí',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_list_off_rounded,
                size: 32,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin resultados',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay mediciones con estado "$_selectedFilter"',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar historial',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
