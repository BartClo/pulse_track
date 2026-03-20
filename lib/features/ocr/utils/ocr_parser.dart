import 'dart:math';

/// Confidence level for parsed values exposed to the UI.
enum ParseConfidence {
  /// Value was found with a clear label (SYS, DIA, PUL) or passes strict validation.
  high,

  /// Value was inferred but still satisfies physiological checks.
  medium,

  /// Value is shaky, outside ideal ranges, or missing relationships.
  low,

  /// Value could not be determined.
  none,
}

/// Output model of the multi-layer OCR pipeline.
///
/// Keeps the parsed values, their confidence labels and metadata required
/// for downstream validation and UI hints.
class OcrResult {
  final int? systolic;
  final int? diastolic;
  final int? pulse;

  final String systolicConfidence;
  final String diastolicConfidence;
  final String pulseConfidence;

  final List<int> candidates;
  final List<int> discardedValues;
  final List<String> warnings;

  final bool requiresManualInput;
  final bool allowRetake;
  final double confidenceScore;

  final String rawText;
  final String cleanedText;

  const OcrResult({
    this.systolic,
    this.diastolic,
    this.pulse,
    this.systolicConfidence = 'low',
    this.diastolicConfidence = 'low',
    this.pulseConfidence = 'low',
    this.candidates = const [],
    this.discardedValues = const [],
    this.warnings = const [],
    this.requiresManualInput = true,
    this.allowRetake = true,
    this.confidenceScore = 0.0,
    this.rawText = '',
    this.cleanedText = '',
  });

  OcrResult copyWith({
    int? systolic,
    int? diastolic,
    int? pulse,
    String? systolicConfidence,
    String? diastolicConfidence,
    String? pulseConfidence,
    List<int>? candidates,
    List<int>? discardedValues,
    List<String>? warnings,
    bool? requiresManualInput,
    bool? allowRetake,
    double? confidenceScore,
    String? rawText,
    String? cleanedText,
  }) {
    return OcrResult(
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      systolicConfidence: systolicConfidence ?? this.systolicConfidence,
      diastolicConfidence: diastolicConfidence ?? this.diastolicConfidence,
      pulseConfidence: pulseConfidence ?? this.pulseConfidence,
      candidates: candidates ?? this.candidates,
      discardedValues: discardedValues ?? this.discardedValues,
      warnings: warnings ?? this.warnings,
      requiresManualInput: requiresManualInput ?? this.requiresManualInput,
      allowRetake: allowRetake ?? this.allowRetake,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawText: rawText ?? this.rawText,
      cleanedText: cleanedText ?? this.cleanedText,
    );
  }
}

/// Utility class for parsing OCR text from blood pressure monitors.
///
/// Implements the multi-layer pipeline:
/// 1. Text cleaning
/// 2. Number extraction & filtering
/// 3. Intelligent assignment
/// 4. Validation & confidence scoring
/// 5. User-facing metadata (warnings, retake flags)
class OcrParser {
  final OcrResult result;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final String rawText;
  final String cleanedText;
  final bool isValid;

  final ParseConfidence systolicConfidence;
  final ParseConfidence diastolicConfidence;
  final ParseConfidence pulseConfidence;
  final double overallConfidence;

  OcrParser._(this.result)
      : systolic = result.systolic,
        diastolic = result.diastolic,
        pulse = result.pulse,
        rawText = result.rawText,
        cleanedText = result.cleanedText,
        isValid = result.systolic != null && result.diastolic != null,
        systolicConfidence = _parseConfidenceLabel(result.systolicConfidence),
        diastolicConfidence = _parseConfidenceLabel(result.diastolicConfidence),
        pulseConfidence = result.pulse != null
            ? _parseConfidenceLabel(result.pulseConfidence)
            : ParseConfidence.none,
        overallConfidence = result.confidenceScore;

  /// Parse raw OCR text and extract blood pressure values.
  factory OcrParser.parse(String text) {
    final pipelineResult = interpretText(
      rawText: text,
    );
    return OcrParser._(pipelineResult);
  }

  /// Create OcrParser from pre-extracted values (e.g., region-based OCR).
  factory OcrParser.fromValues({
    int? systolic,
    int? diastolic,
    int? pulse,
    required String rawText,
    ParseConfidence confidence = ParseConfidence.medium,
  }) {
    final cleaned = _cleanText(rawText);
    final baseLabel = _confidenceLabelFromParseConfidence(confidence);

    final warnings = <String>[];
    bool requiresManualInput = systolic == null || diastolic == null;
    if (requiresManualInput) {
      warnings.add(
        'No se detectaron todos los valores. Completa los datos manualmente.',
      );
    }

    final validation = _validateAssignment(
      systolic,
      diastolic,
      pulse,
    );
    warnings.addAll(validation.warnings);

    final systolicConfidence = _resolveConfidence(
      baseLabel,
      systolic,
      _ValueBand.systolic,
      validation.systolicRangeValid && validation.relationshipValid,
    );
    final diastolicConfidence = _resolveConfidence(
      baseLabel,
      diastolic,
      _ValueBand.diastolic,
      validation.diastolicRangeValid && validation.relationshipValid,
    );
    final pulseConfidence = _resolveConfidence(
      baseLabel,
      pulse,
      _ValueBand.pulse,
      validation.pulseRangeValid,
    );

    final confidenceScore = _calculateConfidenceScore(
      systolicConfidence,
      diastolicConfidence,
      pulse != null ? pulseConfidence : null,
    );

    final result = OcrResult(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      systolicConfidence: systolic != null ? systolicConfidence : 'low',
      diastolicConfidence: diastolic != null ? diastolicConfidence : 'low',
      pulseConfidence: pulse != null ? pulseConfidence : 'low',
      rawText: rawText,
      cleanedText: cleaned,
      candidates: [systolic, diastolic, pulse].whereType<int>().toList(),
      discardedValues: const [],
      warnings: warnings,
      requiresManualInput: requiresManualInput,
      allowRetake: requiresManualInput ||
          warnings.isNotEmpty ||
          systolicConfidence == 'low' ||
          diastolicConfidence == 'low',
      confidenceScore: confidenceScore,
    );

    return OcrParser._(result);
  }

  /// Public entry point for the multi-layer OCR pipeline.
  static OcrResult interpretText({
    required String rawText,
    List<int> seedNumbers = const [],
  }) {
    final cleaned = _cleanText(rawText);
    final originalUpper = rawText.toUpperCase();
    final labeledValues = _extractLabeledValues(originalUpper);

    final extractedNumbers = _extractNumbers(cleaned);
    final mergedNumbers = <int>[
      ...seedNumbers,
      ...extractedNumbers,
      ...labeledValues.values,
    ];

    final discardedValues =
        mergedNumbers.where((n) => n < 40 || n > 200).toList();

    final inRangeNumbers =
        mergedNumbers.where((n) => n >= 40 && n <= 200).toList();
    final correctedNumbers = _applyCommonConfusionCorrections(inRangeNumbers);
    final groupedNumbers = _groupSimilarValues(correctedNumbers);
    final filteredCandidates = _filterCandidates(groupedNumbers);

    final assignment = _assignValues(
      filteredCandidates,
      labeledValues: labeledValues,
    );

    final validation = _validateAssignment(
      assignment.systolic,
      assignment.diastolic,
      assignment.pulse,
    );
    final warnings = [...validation.warnings];

    if (filteredCandidates.length < 3) {
      warnings.add(
        'Menos de tres números válidos detectados. Requiere confirmación manual.',
      );
    }

    final systolicConfidence = _resolveConfidence(
      assignment.systolicConfidenceLabel,
      assignment.systolic,
      _ValueBand.systolic,
      validation.systolicRangeValid && validation.differenceValid,
    );

    final diastolicConfidence = _resolveConfidence(
      assignment.diastolicConfidenceLabel,
      assignment.diastolic,
      _ValueBand.diastolic,
      validation.diastolicRangeValid && validation.differenceValid,
    );

    final pulseConfidence = _resolveConfidence(
      assignment.pulseConfidenceLabel,
      assignment.pulse,
      _ValueBand.pulse,
      validation.pulseRangeValid,
    );

    final requiresManualInput =
        assignment.systolic == null || assignment.diastolic == null;
    final allowRetake = requiresManualInput ||
        warnings.isNotEmpty ||
        systolicConfidence == 'low' ||
        diastolicConfidence == 'low';

    final confidenceScore = _calculateConfidenceScore(
      systolicConfidence,
      diastolicConfidence,
      assignment.pulse != null ? pulseConfidence : null,
    );

    return OcrResult(
      systolic: assignment.systolic,
      diastolic: assignment.diastolic,
      pulse: assignment.pulse,
      systolicConfidence: systolicConfidence,
      diastolicConfidence: diastolicConfidence,
      pulseConfidence: assignment.pulse != null ? pulseConfidence : 'low',
      candidates: filteredCandidates,
      discardedValues: discardedValues,
      warnings: warnings,
      requiresManualInput: requiresManualInput,
      allowRetake: allowRetake,
      confidenceScore: confidenceScore,
      rawText: rawText,
      cleanedText: cleaned,
    );
  }

  /// Clean OCR text by fixing common misrecognitions and removing noise.
  static String normalizeText(String text) => _cleanText(text);

  /// Extract candidate numbers directly from text (utility for other services).
  static List<int> extractNumbers(String text) =>
      _extractNumbers(_cleanText(text));

  static ParseConfidence _parseConfidenceLabel(String label) {
    switch (label) {
      case 'high':
        return ParseConfidence.high;
      case 'medium':
        return ParseConfidence.medium;
      case 'low':
        return ParseConfidence.low;
      default:
        return ParseConfidence.none;
    }
  }

  static String _confidenceLabelFromParseConfidence(ParseConfidence value) {
    switch (value) {
      case ParseConfidence.high:
        return 'high';
      case ParseConfidence.medium:
        return 'medium';
      case ParseConfidence.low:
      case ParseConfidence.none:
        return 'low';
    }
  }

  static double _calculateConfidenceScore(
    String systolicConfidence,
    String diastolicConfidence, [
    String? pulseConfidence,
  ]) {
    final scores = <double>[
      _confidenceNumericValue(systolicConfidence),
      _confidenceNumericValue(diastolicConfidence),
      if (pulseConfidence != null) _confidenceNumericValue(pulseConfidence),
    ];

    return scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
  }

  static double _confidenceNumericValue(String label) {
    switch (label) {
      case 'high':
        return 1.0;
      case 'medium':
        return 0.6;
      default:
        return 0.2;
    }
  }

  static String _resolveConfidence(
    String baseLabel,
    int? value,
    _ValueBand band,
    bool relationshipValid,
  ) {
    if (value == null) return 'low';
    if (!band.isWithin(value)) return 'low';

    int rank = _labelToRank(baseLabel);
    if (!relationshipValid) {
      rank = min(rank, 2);
    }

    if (band.isPreferred(value)) {
      rank = max(rank, 3);
    } else {
      rank = max(rank, 2);
    }

    return _rankToLabel(rank);
  }

  static int _labelToRank(String label) {
    switch (label) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      default:
        return 1;
    }
  }

  static String _rankToLabel(int rank) {
    if (rank >= 3) return 'high';
    if (rank == 2) return 'medium';
    return 'low';
  }
}

/// Numeric constraints for physiological validation.
class _ValueBand {
  final int min;
  final int max;
  final int preferredMin;
  final int preferredMax;

  const _ValueBand({
    required this.min,
    required this.max,
    required this.preferredMin,
    required this.preferredMax,
  });

  bool isWithin(int value) => value >= min && value <= max;
  bool isPreferred(int value) => value >= preferredMin && value <= preferredMax;

  static const systolic = _ValueBand(
    min: 90,
    max: 200,
    preferredMin: 105,
    preferredMax: 135,
  );

  static const diastolic = _ValueBand(
    min: 50,
    max: 130,
    preferredMin: 60,
    preferredMax: 85,
  );

  static const pulse = _ValueBand(
    min: 40,
    max: 150,
    preferredMin: 55,
    preferredMax: 95,
  );
}

class _AssignmentResult {
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final List<int> orderedCandidates;
  final String systolicConfidenceLabel;
  final String diastolicConfidenceLabel;
  final String pulseConfidenceLabel;

  const _AssignmentResult({
    this.systolic,
    this.diastolic,
    this.pulse,
    this.orderedCandidates = const [],
    this.systolicConfidenceLabel = 'low',
    this.diastolicConfidenceLabel = 'low',
    this.pulseConfidenceLabel = 'low',
  });
}

class _ValidationOutcome {
  final bool systolicRangeValid;
  final bool diastolicRangeValid;
  final bool pulseRangeValid;
  final bool relationshipValid;
  final bool differenceValid;
  final List<String> warnings;

  const _ValidationOutcome({
    required this.systolicRangeValid,
    required this.diastolicRangeValid,
    required this.pulseRangeValid,
    required this.relationshipValid,
    required this.differenceValid,
    required this.warnings,
  });
}

String _cleanText(String text) {
  if (text.isEmpty) return '';
  String upper = text.toUpperCase();
  upper = upper.replaceAll('8O', '80');
  final buffer = StringBuffer();

  for (final char in upper.split('')) {
    switch (char) {
      case 'O':
      case 'Q':
        buffer.write('0');
        break;
      case 'I':
      case 'L':
      case '|':
        buffer.write('1');
        break;
      case 'S':
        buffer.write('5');
        break;
      case 'B':
        buffer.write('8');
        break;
      default:
        buffer.write(char);
        break;
    }
  }

  final replaced = buffer.toString();
  final digitsAndSpaces = replaced.replaceAll(RegExp(r'[^0-9 ]'), ' ');
  return digitsAndSpaces.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<int> _extractNumbers(String text) {
  if (text.isEmpty) return const [];
  final pattern = RegExp(r'\d{2,3}');
  return pattern
      .allMatches(text)
      .map((m) => int.tryParse(m.group(0)!))
      .where((value) => value != null)
      .cast<int>()
      .toList();
}

Map<String, int> _extractLabeledValues(String text) {
  final result = <String, int>{};
  if (text.isEmpty) return result;

  int? parseMatch(RegExp pattern) =>
      int.tryParse(pattern.firstMatch(text)?.group(1) ?? '');

  int? systolic = parseMatch(RegExp(r'SYS[:\s]*(\d{2,3})'));
  systolic ??= parseMatch(RegExp(r'SYST(?:OLIC)?[:\s]*(\d{2,3})'));
  final systolicValue =
      (systolic != null && _ValueBand.systolic.isWithin(systolic))
          ? systolic
          : null;
  if (systolicValue != null) result['systolic'] = systolicValue;

  int? diastolic = parseMatch(RegExp(r'DIA[:\s]*(\d{2,3})'));
  diastolic ??= parseMatch(RegExp(r'DIAST(?:OLIC)?[:\s]*(\d{2,3})'));
  final diastolicValue =
      (diastolic != null && _ValueBand.diastolic.isWithin(diastolic))
          ? diastolic
          : null;
  if (diastolicValue != null) result['diastolic'] = diastolicValue;

  int? pulse = parseMatch(RegExp(r'(?:PUL|PULSE|BPM)[:\s]*(\d{2,3})'));
  pulse ??= parseMatch(RegExp(r'(\d{2,3})[:\s]*BPM'));
  final pulseValue =
      (pulse != null && _ValueBand.pulse.isWithin(pulse)) ? pulse : null;
  if (pulseValue != null) result['pulse'] = pulseValue;

  return result;
}

List<int> _applyCommonConfusionCorrections(List<int> numbers) {
  if (numbers.isEmpty) return const <int>[];
  final counts = <int, int>{};
  for (final value in numbers) {
    counts[value] = (counts[value] ?? 0) + 1;
  }

  final preferred5060 = _preferredValue(counts, 50, 60, tieBreaker: 60);
  final preferred9596 = _preferredValue(counts, 95, 96, tieBreaker: 95);

  return numbers
      .map((value) {
        if (preferred5060 != null && (value == 50 || value == 60)) {
          return preferred5060;
        }
        if (preferred9596 != null && (value == 95 || value == 96)) {
          return preferred9596;
        }
        return value;
      })
      .toList();
}

int? _preferredValue(
  Map<int, int> counts,
  int first,
  int second, {
  required int tieBreaker,
}) {
  final firstCount = counts[first] ?? 0;
  final secondCount = counts[second] ?? 0;
  if (firstCount == 0 && secondCount == 0) return null;
  if (firstCount == secondCount) return tieBreaker;
  return firstCount > secondCount ? first : second;
}

List<int> _groupSimilarValues(
  List<int> numbers, {
  int tolerance = 2,
}) {
  if (numbers.isEmpty) return const <int>[];

  final frequencies = <int, int>{};
  for (final value in numbers) {
    frequencies[value] = (frequencies[value] ?? 0) + 1;
  }

  final consumed = <int>{};
  final sortedKeys = frequencies.keys.toList()..sort();
  final canonical = <int>[];

  for (final value in sortedKeys) {
    if (consumed.contains(value)) continue;

    final cluster = <int>[];
    for (final candidate in sortedKeys) {
      if (consumed.contains(candidate)) continue;
      if ((candidate - value).abs() <= tolerance) {
        cluster.add(candidate);
      }
    }

    if (cluster.isEmpty) continue;

    int best = cluster.first;
    for (final candidate in cluster.skip(1)) {
      final bestCount = frequencies[best] ?? 0;
      final candidateCount = frequencies[candidate] ?? 0;
      if (candidateCount > bestCount) {
        best = candidate;
      } else if (candidateCount == bestCount && candidate > best) {
        best = candidate;
      }
    }

    canonical.add(best);
    consumed.addAll(cluster);
  }

  canonical.sort((a, b) => b.compareTo(a));
  return canonical;
}

List<int> _filterCandidates(List<int> numbers) {
  final filtered = numbers
      .where((value) => value >= 40 && value <= 200)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  return filtered;
}

_AssignmentResult _assignValues(
  List<int> sortedCandidates, {
  Map<String, int> labeledValues = const {},
}) {
  if (sortedCandidates.isEmpty) {
    return const _AssignmentResult(orderedCandidates: []);
  }

  final remaining = List<int>.from(sortedCandidates);

  int? systolic = labeledValues['systolic'];
  String systolicConfidence = systolic != null ? 'high' : 'medium';
  if (systolic != null) {
    remaining.remove(systolic);
  } else {
    for (final value in List<int>.from(remaining)) {
      if (value >= _ValueBand.systolic.min) {
        systolic = value;
        remaining.remove(value);
        break;
      }
    }
  }

  int? pulse = labeledValues['pulse'];
  String pulseConfidence = pulse != null ? 'high' : 'medium';
  if (pulse != null) {
    remaining.remove(pulse);
  } else if (remaining.isNotEmpty) {
    pulse = _closestToTarget(
      remaining,
      target: 75,
      min: _ValueBand.pulse.min,
      max: _ValueBand.pulse.max,
    );
    if (pulse != null) {
      pulseConfidence = 'medium';
      remaining.remove(pulse);
    }
  }

  int? diastolic = labeledValues['diastolic'];
  String diastolicConfidence = diastolic != null ? 'high' : 'medium';
  if (diastolic != null) {
    remaining.remove(diastolic);
  } else if (remaining.isNotEmpty) {
    final candidates = remaining
        .where((value) => value <= _ValueBand.diastolic.max)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (final value in candidates) {
      if (systolic == null || value < systolic) {
        diastolic = value;
        remaining.remove(value);
        break;
      }
    }
  }

  if (diastolic == null && remaining.isNotEmpty) {
    diastolic = remaining
        .where((value) => systolic == null || value < systolic)
        .fold<int?>(null, (acc, value) {
      if (acc == null) return value;
      return value > acc ? value : acc;
    });
  }

  if (systolic != null && diastolic != null && systolic <= diastolic) {
    final temp = systolic;
    systolic = diastolic;
    diastolic = temp;

    final tempLabel = systolicConfidence;
    systolicConfidence = diastolicConfidence;
    diastolicConfidence = tempLabel;
  }

  if (systolic == null) systolicConfidence = 'low';
  if (diastolic == null) diastolicConfidence = 'low';
  if (pulse == null) pulseConfidence = 'low';

  return _AssignmentResult(
    systolic: systolic,
    diastolic: diastolic,
    pulse: pulse,
    orderedCandidates: sortedCandidates,
    systolicConfidenceLabel: systolicConfidence,
    diastolicConfidenceLabel: diastolicConfidence,
    pulseConfidenceLabel: pulseConfidence,
  );
}

int? _closestToTarget(
  List<int> values, {
  required int target,
  required int min,
  required int max,
}) {
  int? bestValue;
  int bestDistance = 1 << 30;
  for (final value in values) {
    if (value < min || value > max) continue;
    final distance = (value - target).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestValue = value;
    }
  }
  return bestValue;
}

_ValidationOutcome _validateAssignment(
  int? systolic,
  int? diastolic,
  int? pulse,
) {
  final warnings = <String>[];

  final systolicValid =
      systolic != null && _ValueBand.systolic.isWithin(systolic);
  final diastolicValid =
      diastolic != null && _ValueBand.diastolic.isWithin(diastolic);
  final pulseValid = pulse == null || _ValueBand.pulse.isWithin(pulse);

  if (systolic != null && !systolicValid) {
    warnings.add('SYS fuera de rango ($systolic).');
  }
  if (diastolic != null && !diastolicValid) {
    warnings.add('DIA fuera de rango ($diastolic).');
  }
  if (pulse != null && !pulseValid) {
    warnings.add('Pulso fuera de rango ($pulse).');
  }

  bool relationshipValid = true;
  bool differenceValid = true;
  if (systolic == null || diastolic == null) {
    relationshipValid = false;
    differenceValid = false;
    warnings.add('Lectura incompleta. Captura SYS y DIA manualmente.');
  } else {
    if (systolic <= diastolic) {
      relationshipValid = false;
      warnings.add('SYS debe ser mayor que DIA.');
    }

    final diff = systolic - diastolic;
    if (diff < 20) {
      differenceValid = false;
      warnings.add('La diferencia SYS-DIA es menor a 20 mmHg.');
    }
  }

  return _ValidationOutcome(
    systolicRangeValid: systolicValid,
    diastolicRangeValid: diastolicValid,
    pulseRangeValid: pulseValid,
    relationshipValid: relationshipValid,
    differenceValid: differenceValid,
    warnings: warnings,
  );
}
