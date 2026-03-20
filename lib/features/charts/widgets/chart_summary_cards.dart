import 'package:flutter/material.dart';

class ChartSummaryCards extends StatelessWidget {
  final String averageValue;
  final int? trend;

  const ChartSummaryCards({super.key, required this.averageValue, this.trend});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Promedio SYS/DIA',
            child: Text(
              averageValue,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Tendencia',
            child: Row(
              children: [
                Icon(
                  Icons.trending_down,
                  color: trend != null && trend! < 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  trend != null ? '${trend! > 0 ? '+' : ''}$trend' : '--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: trend != null && trend! < 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _SummaryCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
