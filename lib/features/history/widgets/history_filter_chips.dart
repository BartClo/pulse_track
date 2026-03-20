import 'package:flutter/material.dart';

class HistoryFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Map<String, int> counts;
  final ValueChanged<String> onFilterChanged;

  const HistoryFilterChips({
    super.key,
    required this.selectedFilter,
    required this.counts,
    required this.onFilterChanged,
  });

  static const _filters = ['Todas', 'Normal', 'Elevada', 'Alta'];

  static const _filterColors = {
    'Todas': Color(0xFF2979FF),
    'Normal': Color(0xFF4CAF50),
    'Elevada': Color(0xFFFFA000),
    'Alta': Color(0xFFF44336),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final count = counts[filter] ?? 0;
          final isSelected = selectedFilter == filter;
          final color = _filterColors[filter]!;

          return FilterChip(
            selected: isSelected,
            label: Text('$filter ($count)'),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : color,
            ),
            backgroundColor: Colors.white,
            selectedColor: color,
            side: BorderSide(
              color: isSelected ? color : const Color(0xFFE0E0E0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
            onSelected: (_) => onFilterChanged(filter),
          );
        },
      ),
    );
  }
}
