import 'package:flutter/material.dart';

enum ChartPeriod { dia, semana, mes }

class PeriodFilterChips extends StatelessWidget {
  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onChanged;

  const PeriodFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _labels = {
    ChartPeriod.dia: 'Día',
    ChartPeriod.semana: 'Semana',
    ChartPeriod.mes: 'Mes',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ChartPeriod.values.map((period) {
        final isSelected = selected == period;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              selected: isSelected,
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  _labels[period]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
              selectedColor: const Color(0xFF2979FF),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF2979FF)
                    : const Color(0xFFE0E0E0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              onSelected: (_) => onChanged(period),
            ),
          ),
        );
      }).toList(),
    );
  }
}
