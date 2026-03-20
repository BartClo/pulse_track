import 'package:flutter/material.dart';

class ReferenceValuesCard extends StatelessWidget {
  const ReferenceValuesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text(
                'Valores de referencia',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow(const Color(0xFF4CAF50), 'Normal', '<130 / <85'),
          const SizedBox(height: 10),
          _buildRow(const Color(0xFFFFA000), 'Elevada', '130-139 / 85-89'),
          const SizedBox(height: 10),
          _buildRow(const Color(0xFFF44336), 'Alta', '≥140 / ≥90'),
        ],
      ),
    );
  }

  Widget _buildRow(Color color, String label, String range) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Text(
          range,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
