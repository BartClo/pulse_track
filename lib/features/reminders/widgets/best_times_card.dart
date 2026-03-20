import 'package:flutter/material.dart';

/// Info card showing best times to measure blood pressure.
///
/// Displays tips for morning, afternoon, and evening measurements.
class BestTimesCard extends StatelessWidget {
  const BestTimesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Light amber/yellow background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alarm_on,
                  color: Color(0xFFE65100),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Mejores momentos para medir',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            'Mañana:',
            'Al despertar, antes del desayuno',
            const Color(0xFFE65100),
          ),
          const SizedBox(height: 8),
          _buildTipItem(
            'Tarde:',
            'Después de descansar un momento',
            const Color(0xFFE65100),
          ),
          const SizedBox(height: 8),
          _buildTipItem(
            'Noche:',
            'Antes de dormir, en calma',
            const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String title, String subtitle, Color titleColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                TextSpan(text: ' $subtitle'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
