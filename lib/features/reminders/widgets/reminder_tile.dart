import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../models/reminder.dart';

/// Widget representing a single reminder card.
///
/// Displays the reminder time, label, toggle switch, and notification info.
/// Matches the Figma design with rounded corners and proper spacing.
class ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final void Function(int hour, int minute)? onTimeChanged;
  final VoidCallback? onTap;

  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
    this.onTimeChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = reminder.enabled;

    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context);
      },
      onDismissed: (direction) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Bell icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: isEnabled
                      ? const Color(0xFF1E88E5)
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Time and label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? Colors.grey.shade700
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Time with edit button
                    Row(
                      children: [
                        Text(
                          reminder.formattedTime,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isEnabled
                                ? Colors.grey.shade800
                                : Colors.grey.shade400,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Edit time button
                        GestureDetector(
                          onTap: () => _showTimePickerModal(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? const Color(
                                      0xFF1E88E5,
                                    ).withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: isEnabled
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reminder.notificationMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle switch
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeThumbColor: const Color(0xFF1E88E5),
                  activeTrackColor: const Color(
                    0xFF1E88E5,
                  ).withValues(alpha: 0.4),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TimePickerBottomSheet(
        initialHour: reminder.hour,
        initialMinute: reminder.minute,
        onTimeSelected: (hour, minute) {
          if (onTimeChanged != null) {
            onTimeChanged!(hour, minute);
          }
        },
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Eliminar recordatorio'),
            content: Text(
              '¿Deseas eliminar el recordatorio de las ${reminder.formattedTime}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Bottom sheet with scrollable time picker
class _TimePickerBottomSheet extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final void Function(int hour, int minute) onTimeSelected;

  const _TimePickerBottomSheet({
    required this.initialHour,
    required this.initialMinute,
    required this.onTimeSelected,
  });

  @override
  State<_TimePickerBottomSheet> createState() => _TimePickerBottomSheetState();
}

class _TimePickerBottomSheetState extends State<_TimePickerBottomSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ),
                const Text(
                  'Editar hora',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {
                    widget.onTimeSelected(_selectedHour, _selectedMinute);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color: Color(0xFF1E88E5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Time picker
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Hours
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourController,
                    itemExtent: 50,
                    selectionOverlay: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedHour = index);
                    },
                    children: List.generate(24, (index) {
                      final isSelected = index == _selectedHour;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 20,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Separator
                const Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                // Minutes
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteController,
                    itemExtent: 50,
                    selectionOverlay: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedMinute = index);
                    },
                    children: List.generate(60, (index) {
                      final isSelected = index == _selectedMinute;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 20,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
