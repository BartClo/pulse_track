import 'package:flutter/material.dart';
import '../widgets/header_widget.dart';
import '../widgets/last_measurement_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/reminder_card.dart';
import '../widgets/quick_action_tile.dart';
import '../../pressure_entry/screens/pressure_entry_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../charts/screens/charts_screen.dart';
import '../../reminders/screens/reminders_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../models/dashboard_data.dart';
import '../../../data/repositories/pressure_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/page_transitions.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<DashboardData> _dashboardStream;

  @override
  void initState() {
    super.initState();
    _dashboardStream = PressureRepository.instance.watchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DashboardData>(
        stream: _dashboardStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? DashboardData.fromReadings([]);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                HeaderWidget(
                  averageValue: data.averageDisplay,
                  todayValue: data.todayDisplay,
                  onProfileTap: () {
                    Navigator.of(
                      context,
                    ).push(FadeScalePageRoute(page: const ProfileScreen()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    children: [
                      if (!data.isEmpty)
                        LastMeasurementCard(
                          systolic: data.latestReading!.systolic,
                          diastolic: data.latestReading!.diastolic,
                          pulse: data.latestReading!.pulse,
                          status: data.latestReading!.status,
                          statusColor: Color(
                            data.latestReading!.statusColorValue,
                          ),
                          timestamp: data.latestReading!.formattedDate,
                        )
                      else
                        _buildEmptyCard(),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Registrar nueva medición',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            SlideUpPageRoute(page: const PressureEntryScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ReminderCard(
                        time: '08:00',
                        day: 'Mañana',
                        onTap: () {
                          Navigator.of(context).push(
                            FadeScalePageRoute(page: const RemindersScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          QuickActionTile(
                            icon: Icons.history_rounded,
                            label: 'Historial',
                            onTap: () {
                              Navigator.of(context).push(
                                SharedAxisPageRoute(
                                  page: const HistoryScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          QuickActionTile(
                            icon: Icons.bar_chart_rounded,
                            label: 'Gráficos',
                            onTap: () {
                              Navigator.of(context).push(
                                SharedAxisPageRoute(page: const ChartsScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          QuickActionTile(
                            icon: Icons.notifications_rounded,
                            label: 'Alarmas',
                            onTap: () {
                              Navigator.of(context).push(
                                FadeScalePageRoute(
                                  page: const RemindersScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.extraLargeRadius,
        boxShadow: AppShadows.small,
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_heart_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('Sin mediciones aún', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Registra tu primera medición para\ncomenzar a monitorear tu salud',
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
            Text('Error al cargar datos', style: AppTextStyles.h3),
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
