import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/onboarding/screens/onboarding_flow_screen.dart';
import 'features/reminders/screens/alarm_screen.dart';
import 'data/datasources/local_db.dart';
import 'services/notification_service.dart';
import 'services/insight_notification_service.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'services/session_service.dart';
import 'data/repositories/pressure_repository.dart';
import 'core/supabase_config.dart';

/// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database
  await LocalDatabase.initialize();

  // Initialize Supabase (if configured)
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // Initialize services
  SupabaseService.instance.initialize();
  AuthService.instance.initialize();

  // Restore any existing Supabase session
  await AuthService.instance.restoreSession();

  // Sync from cloud if logged in (non-blocking)
  _performStartupSync();

  // Initialize notification service
  await NotificationService.instance.initialize();

  // Sync existing reminders with notifications
  await NotificationService.instance.syncAllReminders();

  // Run daily insight checks (in-app trigger)
  final recentReadings = await PressureRepository.instance.getReadingsLastDays(
    2,
  );
  await InsightNotificationService.instance.runDailyCheck(recentReadings);

  runApp(const MyApp());
}

/// Performs cloud sync on app startup (non-blocking).
void _performStartupSync() async {
  try {
    final isLoggedIn = await SessionService.instance.isLoggedIn;
    if (isLoggedIn) {
      await SyncService.instance.syncFromCloud();
    }
  } catch (e) {
    print('[main] Startup sync failed: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Set up alarm callback
    NotificationService.onAlarmTriggered = _showAlarmScreen;
  }

  void _showAlarmScreen(int reminderId, String label) {
    // Navigate to alarm screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) =>
            AlarmScreen(reminderId: reminderId, reminderLabel: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PulseTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2979FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),
      home: const AppEntryScreen(),
    );
  }
}
