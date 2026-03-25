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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Stream initialized once in initState, not recreated on every build
  late final Stream<DashboardData> _dashboardStream;

  @override
  void initState() {
    super.initState();
    _dashboardStream = PressureRepository.instance.watchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: StreamBuilder<DashboardData>(
        stream: _dashboardStream,
        builder: (context, snapshot) {
          // Error state
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          // Loading state (only show on initial load)
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Data state - use pre-computed DashboardData
          final data = snapshot.data ?? DashboardData.fromReadings([]);

          return SingleChildScrollView(
            child: Column(
              children: [
                HeaderWidget(
                  averageValue: data.averageDisplay,
                  todayValue: data.todayDisplay,
                  onProfileTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
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
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Registrar nueva medición',
                        icon: Icons.add,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PressureEntryScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ReminderCard(
                        time: '08:00',
                        day: 'Mañana',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RemindersScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          QuickActionTile(
                            icon: Icons.history,
                            label: 'Historial',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          QuickActionTile(
                            icon: Icons.bar_chart,
                            label: 'Gráficos',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ChartsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          QuickActionTile(
                            icon: Icons.notifications_outlined,
                            label: 'Alarmas',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RemindersScreen(),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin mediciones aún',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra tu primera medición',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error al cargar datos',
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
