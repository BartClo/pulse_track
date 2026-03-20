import 'package:flutter/material.dart';

class DateSectionHeader extends StatelessWidget {
  final DateTime date;

  const DateSectionHeader({super.key, required this.date});

  static const _months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  @override
  Widget build(BuildContext context) {
    final day = date.day;
    final month = _months[date.month - 1];
    final year = date.year;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        '$day DE $month DE $year',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
