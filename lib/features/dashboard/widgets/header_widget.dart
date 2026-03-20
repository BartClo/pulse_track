import 'package:flutter/material.dart';
import 'stats_card.dart';

class HeaderWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String averageLabel;
  final String averageValue;
  final String todayLabel;
  final String todayValue;
  final VoidCallback? onProfileTap;

  const HeaderWidget({
    super.key,
    this.title = 'PulseTrack',
    this.subtitle = 'Bienvenido de nuevo',
    this.averageLabel = 'Promedio 7 días',
    this.averageValue = '---/---',
    this.todayLabel = 'Hoy',
    this.todayValue = '0 mediciones',
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2979FF), Color(0xFF448AFF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatsCard(label: averageLabel, value: averageValue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(label: todayLabel, value: todayValue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
