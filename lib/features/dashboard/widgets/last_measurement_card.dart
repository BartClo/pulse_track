import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LastMeasurementCard extends StatefulWidget {
  final int systolic;
  final int diastolic;
  final int pulse;
  final String status;
  final Color statusColor;
  final String timestamp;

  const LastMeasurementCard({
    super.key,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    this.status = 'Normal',
    this.statusColor = Colors.green,
    this.timestamp = '',
  });

  @override
  State<LastMeasurementCard> createState() => _LastMeasurementCardState();
}

class _LastMeasurementCardState extends State<LastMeasurementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.extraLargeRadius,
            boxShadow: AppShadows.medium,
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Última medición', style: AppTextStyles.h4),
                    _StatusBadge(
                      label: widget.status,
                      color: widget.statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BpValue(
                      label: 'SYS',
                      value: widget.systolic,
                      unit: 'mmHg',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 32,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    _BpValue(
                      label: 'DIA',
                      value: widget.diastolic,
                      unit: 'mmHg',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.mediumRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: AppColors.error.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pulso: ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${widget.pulse}',
                        style: AppTextStyles.labelLarge.copyWith(fontSize: 16),
                      ),
                      Text(
                        ' bpm',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Text(widget.timestamp, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BpValue extends StatelessWidget {
  final String label;
  final int value;
  final String unit;

  const _BpValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text('$value', style: AppTextStyles.bpValue),
        const SizedBox(height: 2),
        Text(unit, style: AppTextStyles.caption),
      ],
    );
  }
}
