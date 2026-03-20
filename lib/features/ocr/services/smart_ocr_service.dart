import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/ocr_parser.dart';

/// Confidence level for OCR-detected values.
enum OcrConfidence {
  high, // Clearly detected and validated
  medium, // Valid but some uncertainty
  low, // Missing or out of range
}

/// Result of smart OCR processing with confidence tracking.
class SmartOcrResult {
  final int? systolic;
  final int? diastolic;
  final int? pulse;

  final OcrConfidence systolicConfidence;
  final OcrConfidence diastolicConfidence;
  final OcrConfidence pulseConfidence;

  final String rawText;
  final List<int> extractedNumbers;
  final String debugInfo;
  final List<String> warnings;
  final bool requiresManualInput;
  final bool allowRetake;
  final double confidenceScore;

  SmartOcrResult({
    this.systolic,
    this.diastolic,
    this.pulse,
    this.systolicConfidence = OcrConfidence.low,
    this.diastolicConfidence = OcrConfidence.low,
    this.pulseConfidence = OcrConfidence.low,
    this.rawText = '',
    this.extractedNumbers = const [],
    this.debugInfo = '',
    this.warnings = const [],
    this.requiresManualInput = true,
    this.allowRetake = true,
    this.confidenceScore = 0.0,
  });

  factory SmartOcrResult.fromOcrResult(
    OcrResult result, {
    String debugInfo = '',
  }) {
    return SmartOcrResult(
      systolic: result.systolic,
      diastolic: result.diastolic,
      pulse: result.pulse,
      systolicConfidence: _toOcrConfidence(result.systolicConfidence),
      diastolicConfidence: _toOcrConfidence(result.diastolicConfidence),
      pulseConfidence: _toOcrConfidence(result.pulseConfidence),
      rawText: result.rawText,
      extractedNumbers: result.candidates,
      warnings: result.warnings,
      requiresManualInput: result.requiresManualInput,
      allowRetake: result.allowRetake,
      confidenceScore: result.confidenceScore,
      debugInfo: debugInfo,
    );
  }

  bool get isValid => systolic != null && diastolic != null;

  bool get isComplete => systolic != null && diastolic != null && pulse != null;

  bool get needsUserConfirmation {
    return requiresManualInput ||
        systolicConfidence == OcrConfidence.low ||
        diastolicConfidence == OcrConfidence.low ||
        pulseConfidence == OcrConfidence.low;
  }

  Map<String, dynamic> toJson() => {
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'confidence': {
      'systolic': systolicConfidence.name,
      'diastolic': diastolicConfidence.name,
      'pulse': pulseConfidence.name,
    },
    'warnings': warnings,
    'requiresManualInput': requiresManualInput,
    'allowRetake': allowRetake,
    'confidenceScore': confidenceScore,
  };

  @override
  String toString() {
    return 'SmartOcrResult(sys: $systolic [${systolicConfidence.name}], '
        'dia: $diastolic [${diastolicConfidence.name}], '
        'pulse: $pulse [${pulseConfidence.name}], '
        'warnings: ${warnings.length})';
  }
}

OcrConfidence _toOcrConfidence(String label) {
  switch (label) {
    case 'high':
      return OcrConfidence.high;
    case 'medium':
      return OcrConfidence.medium;
    default:
      return OcrConfidence.low;
  }
}

/// Smart OCR service that works across different blood pressure monitors.
///
/// Uses multiple strategies:
/// 1. Full image OCR with the multi-layer parsing pipeline
/// 2. Region-based OCR (top/middle/bottom) for fallback
/// 3. Validation + confidence scoring with user confirmation metadata
///
/// Does NOT rely on fixed layouts or labels.
class SmartOcrService {
  SmartOcrService._();

  static final SmartOcrService _instance = SmartOcrService._();
  static SmartOcrService get instance => _instance;

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process image using smart detection strategies.
  Future<SmartOcrResult> processImage(File imageFile) async {
    final debugBuffer = StringBuffer();
    debugBuffer.writeln('═══════════════════════════════════');
    debugBuffer.writeln('Smart OCR Processing');
    debugBuffer.writeln('═══════════════════════════════════');

    // Strategy 1: Full image OCR
    final fullImageResult = await _processFullImage(imageFile, debugBuffer);

    if (!_needsFallback(fullImageResult)) {
      debugBuffer.writeln('✓ Full image OCR sufficient');
      final result = SmartOcrResult.fromOcrResult(
        fullImageResult,
        debugInfo: debugBuffer.toString(),
      );
      debugPrint(debugBuffer.toString());
      return result;
    }

    // Strategy 2: Region-based OCR to recover missing values
    debugBuffer.writeln('───────────────────────────────────');
    debugBuffer.writeln('Trying region-based OCR...');
    final regionResult = await _processRegionBased(imageFile, debugBuffer);

    final mergedResult = _combineResults(
      fullImageResult,
      regionResult,
      debugBuffer,
    );

    debugBuffer.writeln('═══════════════════════════════════');
    debugBuffer.writeln(
      'Final Result: ${mergedResult.systolic}/${mergedResult.diastolic} pulse ${mergedResult.pulse}',
    );
    debugBuffer.writeln(
      'Confidence: ${(mergedResult.confidenceScore * 100).toStringAsFixed(0)}%',
    );
    debugBuffer.writeln('Warnings: ${mergedResult.warnings}');
    debugBuffer.writeln('═══════════════════════════════════');

    debugPrint(debugBuffer.toString());
    return SmartOcrResult.fromOcrResult(
      mergedResult,
      debugInfo: debugBuffer.toString(),
    );
  }

  bool _needsFallback(OcrResult result) {
    return result.requiresManualInput ||
        result.systolicConfidence == 'low' ||
        result.diastolicConfidence == 'low';
  }

  /// Process the full image with smart text parsing.
  Future<OcrResult> _processFullImage(
    File imageFile,
    StringBuffer debug,
  ) async {
    debug.writeln('Processing full image...');

    final passes = <_OcrPassSnapshot>[];

    final originalPass = await _runOcrPass(
      'Original',
      InputImage.fromFile(imageFile),
      debug,
    );
    passes.add(originalPass);

    final processedFile = await _buildProcessedImage(imageFile, debug);
    if (processedFile != null) {
      try {
        final processedPass = await _runOcrPass(
          'Processed',
          InputImage.fromFile(processedFile),
          debug,
        );
        passes.add(processedPass);
      } finally {
        try {
          await processedFile.delete();
        } catch (_) {}
      }
    } else {
      debug.writeln('Processed pass skipped (preprocessing failed).');
    }

    final combinedRawText = passes
        .map((pass) => '[${pass.label}] ${pass.text}'.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');

    final seeds = passes.expand((pass) => pass.numbers).toList();
    debug.writeln('Merged OCR seeds: $seeds');

    final result = OcrParser.interpretText(
      rawText: combinedRawText.isNotEmpty ? combinedRawText : originalPass.text,
      seedNumbers: seeds,
    );
    debug.writeln('Candidates: ${result.candidates}');
    debug.writeln(
      'Confidences: SYS ${result.systolicConfidence}, DIA ${result.diastolicConfidence}, PUL ${result.pulseConfidence}',
    );

    return result;
  }

  Future<_OcrPassSnapshot> _runOcrPass(
    String label,
    InputImage inputImage,
    StringBuffer debug,
  ) async {
    debug.writeln('$label OCR pass...');
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final text = recognizedText.text.trim();
    final numbers = OcrParser.extractNumbers(text);
    debug.writeln('$label text: "$text"');
    debug.writeln('$label numbers: $numbers');
    return _OcrPassSnapshot(label: label, text: text, numbers: numbers);
  }

  Future<File?> _buildProcessedImage(File source, StringBuffer debug) async {
    try {
      final bytes = await source.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        debug.writeln('Processed pass skipped: unable to decode image.');
        return null;
      }

      final upscaleWidth = original.width * 2;
      final upscaleHeight = original.height * 2;
      var processed = img.copyResize(
        original,
        width: upscaleWidth,
        height: upscaleHeight,
      );
      processed = img.grayscale(processed);
      processed = img.adjustColor(processed, contrast: 2.0);
      processed = _applyBinaryThreshold(processed, threshold: 128);

      final tempDir = await getTemporaryDirectory();
      final processedPath =
          '${tempDir.path}/ocr_processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(processed, quality: 100));
      debug.writeln('Processed image generated: $processedPath');
      return processedFile;
    } catch (error) {
      debug.writeln('Processed pass skipped: $error');
      return null;
    }
  }

  /// Process image using region-based detection (top/middle/bottom).
  Future<OcrResult> _processRegionBased(
    File imageFile,
    StringBuffer debug,
  ) async {
    debug.writeln('Processing by regions...');

    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      debug.writeln('ERROR: Could not decode image');
      return const OcrResult(rawText: '', cleanedText: '');
    }

    final height = originalImage.height;
    final regionHeight = height ~/ 3;
    final tempDir = await getTemporaryDirectory();

    final topText = await _captureRegionText(
      originalImage,
      0,
      regionHeight,
      '${tempDir.path}/region_top.jpg',
      'TOP',
      debug,
    );

    final middleText = await _captureRegionText(
      originalImage,
      regionHeight,
      regionHeight,
      '${tempDir.path}/region_middle.jpg',
      'MIDDLE',
      debug,
    );

    final bottomText = await _captureRegionText(
      originalImage,
      regionHeight * 2,
      height - (regionHeight * 2),
      '${tempDir.path}/region_bottom.jpg',
      'BOTTOM',
      debug,
    );

    final regionSeedNumbers = <int>[
      ...OcrParser.extractNumbers(topText),
      ...OcrParser.extractNumbers(middleText),
      ...OcrParser.extractNumbers(bottomText),
    ];

    final regionRawText =
        'TOP: $topText\nMIDDLE: $middleText\nBOTTOM: $bottomText';
    final result = OcrParser.interpretText(
      rawText: regionRawText,
      seedNumbers: regionSeedNumbers,
    );

    debug.writeln('Region-based candidates: ${result.candidates}');
    debug.writeln('Region warnings: ${result.warnings}');

    return result;
  }

  /// Process a single region of the image.
  Future<String> _captureRegionText(
    img.Image originalImage,
    int yOffset,
    int regionHeight,
    String tempPath,
    String regionName,
    StringBuffer debug,
  ) async {
    final croppedRegion = img.copyCrop(
      originalImage,
      x: 0,
      y: yOffset,
      width: originalImage.width,
      height: regionHeight,
    );

    final regionFile = File(tempPath);
    await regionFile.writeAsBytes(img.encodeJpg(croppedRegion, quality: 95));

    final inputImage = InputImage.fromFile(regionFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final text = recognizedText.text.trim();

    debug.writeln('$regionName: "$text"');

    try {
      await regionFile.delete();
    } catch (_) {}

    return text;
  }

  OcrResult _combineResults(
    OcrResult fullResult,
    OcrResult regionResult,
    StringBuffer debug,
  ) {
    debug.writeln('Combining results...');
    debug.writeln('Full candidates: ${fullResult.candidates}');
    debug.writeln('Region candidates: ${regionResult.candidates}');

    final mergedText = [
      fullResult.rawText,
      regionResult.rawText,
    ].where((text) => text.isNotEmpty).join('\n');

    final mergedNumbers = <int>[
      ...fullResult.candidates,
      ...regionResult.candidates,
    ];

    final merged = OcrParser.interpretText(
      rawText: mergedText,
      seedNumbers: mergedNumbers,
    );

    final mergedWarnings = {
      ...fullResult.warnings,
      ...regionResult.warnings,
      ...merged.warnings,
    }.where((w) => w.isNotEmpty).toList();

    return merged.copyWith(warnings: mergedWarnings);
  }

  void dispose() {
    _textRecognizer.close();
  }
}

img.Image _applyBinaryThreshold(img.Image image, {int threshold = 128}) {
  final result = img.Image.from(image);
  final clampedThreshold = threshold.clamp(0, 255);

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final luminance = img.getLuminance(pixel);
      final value = luminance >= clampedThreshold ? 255 : 0;
      result.setPixelRgba(x, y, value, value, value, 255);
    }
  }

  return result;
}

class _OcrPassSnapshot {
  final String label;
  final String text;
  final List<int> numbers;

  _OcrPassSnapshot({
    required this.label,
    required this.text,
    required this.numbers,
  });
}

/// Extension to add copyWith functionality.
extension SmartOcrResultExtension on SmartOcrResult {
  SmartOcrResult copyWith({
    int? systolic,
    int? diastolic,
    int? pulse,
    OcrConfidence? systolicConfidence,
    OcrConfidence? diastolicConfidence,
    OcrConfidence? pulseConfidence,
    String? rawText,
    List<int>? extractedNumbers,
    String? debugInfo,
    List<String>? warnings,
    bool? requiresManualInput,
    bool? allowRetake,
    double? confidenceScore,
  }) {
    return SmartOcrResult(
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      systolicConfidence: systolicConfidence ?? this.systolicConfidence,
      diastolicConfidence: diastolicConfidence ?? this.diastolicConfidence,
      pulseConfidence: pulseConfidence ?? this.pulseConfidence,
      rawText: rawText ?? this.rawText,
      extractedNumbers: extractedNumbers ?? this.extractedNumbers,
      debugInfo: debugInfo ?? this.debugInfo,
      warnings: warnings ?? this.warnings,
      requiresManualInput: requiresManualInput ?? this.requiresManualInput,
      allowRetake: allowRetake ?? this.allowRetake,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}
