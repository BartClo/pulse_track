import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/reminder.dart';
import '../../../data/repositories/reminder_repository.dart';
import '../../../services/notification_service.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/notification_permission_card.dart';
import '../widgets/best_times_card.dart';
import '../widgets/add_reminder_button.dart';

/// Screen for managing reminders.
///
/// Displays a list of reminders with toggle and delete functionality.
/// Uses StreamBuilder for reactive updates.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final Stream<List<Reminder>> _remindersStream;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    _remindersStream = ReminderRepository.instance.watchAllReminders();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final hasPermission = await NotificationService.instance.checkPermission();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = hasPermission;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await NotificationService.instance.requestPermission();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = granted;
      });
      if (!granted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permisos necesarios'),
        content: const Text(
          'Para recibir recordatorios, necesitas habilitar las notificaciones '
          'en la configuración de tu dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddReminderDialog() async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Selecciona la hora del recordatorio',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            colorScheme: const ColorScheme.light(primary: Color(0xFF1E88E5)),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final label = Reminder.suggestLabel(selectedTime.hour);
      final reminder = Reminder(
        hour: selectedTime.hour,
        minute: selectedTime.minute,
        label: label,
        enabled: true,
        createdAt: DateTime.now(),
      );

      await ReminderRepository.instance.addReminder(reminder);

      // Schedule the notification
      final savedReminder =
          (await ReminderRepository.instance.getAllReminders()).firstWhere(
            (r) =>
                r.hour == selectedTime.hour && r.minute == selectedTime.minute,
          );
      await NotificationService.instance.scheduleReminder(savedReminder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recordatorio agregado: ${reminder.formattedTime}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleReminder(Reminder reminder, bool enabled) async {
    await ReminderRepository.instance.toggleReminder(reminder.id, enabled);

    // Update notification
    final updatedReminder = reminder.copyWith(enabled: enabled);
    if (enabled) {
      await NotificationService.instance.scheduleReminder(updatedReminder);
    } else {
      await NotificationService.instance.cancelReminder(reminder.id);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    await NotificationService.instance.cancelReminder(reminder.id);
    await ReminderRepository.instance.removeReminder(reminder.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recordatorio de las ${reminder.formattedTime} eliminado',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              // Re-add the reminder
              await ReminderRepository.instance.addReminder(reminder);
              if (reminder.enabled) {
                await NotificationService.instance.scheduleReminder(reminder);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _updateReminderTime(
    Reminder reminder,
    int hour,
    int minute,
  ) async {
    // Update the label based on new time
    final newLabel = Reminder.suggestLabel(hour);

    // Create updated reminder
    final updatedReminder = reminder.copyWith(
      hour: hour,
      minute: minute,
      label: newLabel,
    );

    // Update in database
    await ReminderRepository.instance.updateReminder(updatedReminder);

    // Update notification if enabled
    if (reminder.enabled) {
      await NotificationService.instance.cancelReminder(reminder.id);
      await NotificationService.instance.scheduleReminder(updatedReminder);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recordatorio actualizado a las ${updatedReminder.formattedTime}',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Recordatorios',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Test notification button
          IconButton(
            icon: const Icon(
              Icons.notifications_active,
              color: Color(0xFF1E88E5),
            ),
            tooltip: 'Probar notificación',
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await NotificationService.instance.showTestNotification();
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Notificación de prueba enviada'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: _remindersStream,
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

          final reminders = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description text
                Text(
                  'Configura alarmas para recordarte tomar tus mediciones diarias',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Reminders list
                if (reminders.isEmpty)
                  _buildEmptyState()
                else
                  ...reminders.map(
                    (reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReminderTile(
                        reminder: reminder,
                        onToggle: (enabled) =>
                            _toggleReminder(reminder, enabled),
                        onDelete: () => _deleteReminder(reminder),
                        onTimeChanged: (hour, minute) =>
                            _updateReminderTime(reminder, hour, minute),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Add button
                AddReminderButton(onPressed: _showAddReminderDialog),

                const SizedBox(height: 20),

                // Permission card (if needed)
                if (!_hasNotificationPermission)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: NotificationPermissionCard(
                      onActivate: _requestNotificationPermission,
                    ),
                  )
                else
                  NotificationPermissionCard(
                    onActivate: () {
                      // Show info about notification settings
                      _showNotificationInfoDialog();
                    },
                  ),

                const SizedBox(height: 16),

                // Best times card
                const BestTimesCard(),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNotificationInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Notificaciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para configurar las notificaciones:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (Platform.isAndroid) ...[
              const Text('1. Abre Configuración'),
              const Text('2. Ve a Aplicaciones > PulseTrack'),
              const Text('3. Activa Notificaciones'),
            ] else ...[
              const Text('1. Abre Configuración'),
              const Text('2. Ve a PulseTrack'),
              const Text('3. Activa Notificaciones'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin recordatorios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega un recordatorio para no olvidar tus mediciones',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
              'Error al cargar recordatorios',
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
